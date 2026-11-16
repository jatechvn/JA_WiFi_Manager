#include "ics_service_repair.h"

#include <iostream>
#include <map>
#include <string>
#include <vector>

namespace {

class MockIcsSystemOps final : public ja_wifi::IIcsSystemOps {
 public:
  struct CallRecord {
    std::string op;
    std::string service;
  };

  std::map<std::wstring, ja_wifi::IcsServiceQueryState> service_states{
      {L"icssvc", ja_wifi::IcsServiceQueryState::kRunning},
      {L"SharedAccess", ja_wifi::IcsServiceQueryState::kRunning},
  };

  // Optional sequence of snapshot responses; when exhausted returns final_snapshot.
  std::vector<ja_wifi::IcsHotspotSnapshot> snapshot_queue;
  ja_wifi::IcsHotspotSnapshot final_snapshot{
      true, ja_wifi::IcsTetheringState::kOff, "JA_Hotspot", "12345678", "Auto", 8, 0, ""};

  // Optional override for StopService / StartServiceByName transitions.
  bool icssvc_hang_start_pending = false;
  bool shared_access_hang_stop_pending = false;

  int64_t now_ms = 0;
  std::vector<CallRecord> calls;
  std::map<std::wstring, int> stop_counts;
  std::map<std::wstring, int> start_counts;

  ja_wifi::IcsHotspotSnapshot ReadHotspotSnapshot() override {
    calls.push_back({"ReadHotspotSnapshot", ""});
    if (!snapshot_queue.empty()) {
      const auto front = snapshot_queue.front();
      snapshot_queue.erase(snapshot_queue.begin());
      return front;
    }
    return final_snapshot;
  }

  ja_wifi::IcsServiceStatus QueryService(const wchar_t* service_name) override {
    ja_wifi::IcsServiceStatus status;
    const auto it = service_states.find(service_name);
    status.state = (it == service_states.end())
                       ? ja_wifi::IcsServiceQueryState::kNotInstalled
                       : it->second;
    return status;
  }

  ja_wifi::IcsServiceOpResult StopService(const wchar_t* service_name) override {
    const std::wstring name(service_name);
    stop_counts[name] += 1;
    calls.push_back({"Stop", ToNarrow(name)});
    if (name == L"SharedAccess" && shared_access_hang_stop_pending) {
      service_states[name] = ja_wifi::IcsServiceQueryState::kStopPending;
    } else {
      service_states[name] = ja_wifi::IcsServiceQueryState::kStopped;
    }
    return {true, 0, ""};
  }

  ja_wifi::IcsServiceOpResult StartServiceByName(
      const wchar_t* service_name) override {
    const std::wstring name(service_name);
    start_counts[name] += 1;
    calls.push_back({"Start", ToNarrow(name)});
    if (name == L"icssvc" && icssvc_hang_start_pending) {
      service_states[name] = ja_wifi::IcsServiceQueryState::kStartPending;
    } else {
      service_states[name] = ja_wifi::IcsServiceQueryState::kRunning;
    }
    return {true, 0, ""};
  }

  void SleepMs(int milliseconds) override { now_ms += milliseconds; }

  int64_t NowMs() override { return now_ms; }

 private:
  static std::string ToNarrow(const std::wstring& w) {
    std::string out;
    out.reserve(w.size());
    for (wchar_t ch : w) {
      out.push_back(static_cast<char>(ch & 0x7F));
    }
    return out;
  }
};

bool Expect(bool cond, const char* expr, int line) {
  if (!cond) {
    std::cerr << "FAIL line " << line << ": " << expr << "\n";
    return false;
  }
  return true;
}

#define CHECK(expr)          \
  do {                       \
    if (!Expect((expr), #expr, __LINE__)) { \
      return false;          \
    }                        \
  } while (false)

int FindCallIndex(const std::vector<MockIcsSystemOps::CallRecord>& calls,
                  const std::string& op,
                  const std::string& service) {
  for (size_t i = 0; i < calls.size(); ++i) {
    if (calls[i].op == op && calls[i].service == service) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

bool ContainsStep(const std::vector<std::string>& steps, const std::string& target) {
  for (const auto& step : steps) {
    if (step == target) {
      return true;
    }
  }
  return false;
}

bool TestNormalRecovery() {
  MockIcsSystemOps ops;
  ops.snapshot_queue.push_back(
      {true, ja_wifi::IcsTetheringState::kOff, "JA_Lab", "pass1234", "Auto", 8, 0, ""});
  ops.final_snapshot = {true,
                        ja_wifi::IcsTetheringState::kOn,
                        "JA_Lab",
                        "pass1234",
                        "FiveGigahertz",
                        8,
                        2,
                        ""};

  ja_wifi::IcsRepairOptions opts{2000, 2000, 1000, 50};
  std::vector<std::string> steps;
  const auto res = ja_wifi::RunNativeIcsRepair(
      &ops, opts, [&](const std::string& s) { steps.push_back(s); });

  CHECK(res.ok);
  CHECK(res.services_recovered);
  CHECK(res.hotspot_state == "On");
  CHECK(res.has_config);
  CHECK(res.config.ssid == "JA_Lab");
  CHECK(res.config.band == "FiveGigahertz");
  CHECK(res.config.client_count == 2);

  const int stop_icssvc = FindCallIndex(ops.calls, "Stop", "icssvc");
  const int stop_shared = FindCallIndex(ops.calls, "Stop", "SharedAccess");
  const int start_shared = FindCallIndex(ops.calls, "Start", "SharedAccess");
  const int start_icssvc = FindCallIndex(ops.calls, "Start", "icssvc");
  CHECK(stop_icssvc >= 0 && stop_shared > stop_icssvc);
  CHECK(start_shared > stop_shared && start_icssvc > start_shared);

  CHECK(ContainsStep(steps, "Read Hotspot profile/state"));
  CHECK(ContainsStep(steps, "Stop icssvc"));
  CHECK(ContainsStep(steps, "Stop SharedAccess"));
  CHECK(ContainsStep(steps, "Start SharedAccess"));
  CHECK(ContainsStep(steps, "Wait SharedAccess Running"));
  CHECK(ContainsStep(steps, "Start icssvc"));
  CHECK(ContainsStep(steps, "Wait icssvc Running"));
  CHECK(ContainsStep(steps, "Wait Hotspot stable"));
  CHECK(ContainsStep(steps, "Verify services Running"));
  return true;
}

bool TestInTransitionAbortsSafely() {
  MockIcsSystemOps ops;
  ops.final_snapshot = {
      true, ja_wifi::IcsTetheringState::kInTransition, "", "", "Auto", 8, 0, ""};

  ja_wifi::IcsRepairOptions opts{1000, 1000, 500, 100};
  const auto res = ja_wifi::RunNativeIcsRepair(&ops, opts);

  CHECK(!res.ok);
  CHECK(!res.services_recovered);
  CHECK(res.hotspot_state == "InTransition");
  CHECK(res.step == "Read Hotspot profile/state");
  CHECK(ops.stop_counts[L"icssvc"] == 0);
  CHECK(ops.stop_counts[L"SharedAccess"] == 0);
  CHECK(ops.start_counts[L"icssvc"] == 0);
  return true;
}

bool TestDelayedSettleWithoutRestart() {
  MockIcsSystemOps ops;
  ops.snapshot_queue.push_back(
      {true, ja_wifi::IcsTetheringState::kOff, "JA", "12345678", "Auto", 8, 0, ""});
  ops.snapshot_queue.push_back(
      {true, ja_wifi::IcsTetheringState::kInTransition, "", "", "Auto", 8, 0, ""});
  ops.snapshot_queue.push_back(
      {true, ja_wifi::IcsTetheringState::kInTransition, "", "", "Auto", 8, 0, ""});
  ops.final_snapshot = {
      true, ja_wifi::IcsTetheringState::kOff, "JA", "12345678", "Auto", 8, 0, ""};

  ja_wifi::IcsRepairOptions opts{2000, 2000, 1000, 100};
  const auto res = ja_wifi::RunNativeIcsRepair(&ops, opts);

  CHECK(res.ok);
  CHECK(res.services_recovered);
  CHECK(res.hotspot_state == "Off");
  CHECK(ops.stop_counts[L"icssvc"] == 1);
  CHECK(ops.stop_counts[L"SharedAccess"] == 1);
  CHECK(ops.start_counts[L"SharedAccess"] == 1);
  CHECK(ops.start_counts[L"icssvc"] == 1);
  return true;
}

bool TestStartTimeoutReportsStep() {
  MockIcsSystemOps ops;
  ops.icssvc_hang_start_pending = true;

  ja_wifi::IcsRepairOptions opts{1000, 600, 500, 100};
  const auto res = ja_wifi::RunNativeIcsRepair(&ops, opts);

  CHECK(!res.ok);
  CHECK(!res.services_recovered);
  CHECK(res.step == "Start icssvc");
  CHECK(!res.error.empty());
  return true;
}

bool TestStopPendingRollbackWithoutKill() {
  MockIcsSystemOps ops;
  ops.shared_access_hang_stop_pending = true;

  ja_wifi::IcsRepairOptions opts{600, 1000, 500, 100};
  const auto res = ja_wifi::RunNativeIcsRepair(&ops, opts);

  CHECK(!res.ok);
  CHECK(!res.services_recovered);
  CHECK(res.step == "Stop SharedAccess");
  CHECK(res.error.find("StopPending") != std::string::npos);
  // icssvc was stopped earlier and must be rolled back via StartServiceByName.
  CHECK(ops.start_counts[L"icssvc"] == 1);
  CHECK(ops.service_states[L"icssvc"] == ja_wifi::IcsServiceQueryState::kRunning);
  return true;
}

bool TestNoProfileOfflineRecovery() {
  MockIcsSystemOps ops;
  ops.final_snapshot = {true,
                        ja_wifi::IcsTetheringState::kNoProfile,
                        "",
                        "",
                        "Auto",
                        8,
                        0,
                        ""};

  ja_wifi::IcsRepairOptions opts{1000, 1000, 500, 50};
  const auto res = ja_wifi::RunNativeIcsRepair(&ops, opts);

  CHECK(res.ok);
  CHECK(res.services_recovered);
  CHECK(res.hotspot_state == "Off");
  CHECK(res.has_config);
  CHECK(res.config.ssid == "Offline / No Profile");
  return true;
}

}  // namespace

int main() {
  int passed = 0;
  int total = 0;

  auto run = [&](const char* name, bool (*fn)()) {
    total += 1;
    if (fn()) {
      passed += 1;
      std::cout << "[PASS] " << name << "\n";
    } else {
      std::cout << "[FAIL] " << name << "\n";
    }
  };

  run("TestNormalRecovery", TestNormalRecovery);
  run("TestInTransitionAbortsSafely", TestInTransitionAbortsSafely);
  run("TestDelayedSettleWithoutRestart", TestDelayedSettleWithoutRestart);
  run("TestStartTimeoutReportsStep", TestStartTimeoutReportsStep);
  run("TestStopPendingRollbackWithoutKill", TestStopPendingRollbackWithoutKill);
  run("TestNoProfileOfflineRecovery", TestNoProfileOfflineRecovery);

  std::cout << "Summary: " << passed << "/" << total << " passed\n";
  return passed == total ? 0 : 1;
}
