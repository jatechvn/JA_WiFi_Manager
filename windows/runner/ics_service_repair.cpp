#include "ics_service_repair.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <windows.h>
#include <winsvc.h>
#include <roapi.h>
#include <winstring.h>
#include <wrl/client.h>

#include <windows.networking.connectivity.h>
#include <windows.networking.networkoperators.h>

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <thread>

namespace ja_wifi {

namespace {

using Microsoft::WRL::ComPtr;
namespace NetConn = ABI::Windows::Networking::Connectivity;
namespace NetOps = ABI::Windows::Networking::NetworkOperators;

class RoInitGuard {
 public:
  explicit RoInitGuard(RO_INIT_TYPE type) { hr_ = ::RoInitialize(type); }
  ~RoInitGuard() {
    if (hr_ == S_OK || hr_ == S_FALSE) {
      ::RoUninitialize();
    }
  }
  RoInitGuard(const RoInitGuard&) = delete;
  RoInitGuard& operator=(const RoInitGuard&) = delete;

  bool IsUsable() const {
    return SUCCEEDED(hr_) || hr_ == RPC_E_CHANGED_MODE;
  }
  HRESULT status() const { return hr_; }

 private:
  HRESULT hr_ = E_FAIL;
};

class ScopedHStringRef {
 public:
  template <size_t N>
  explicit ScopedHStringRef(const wchar_t (&text)[N]) {
    hr_ = ::WindowsCreateStringReference(
        text, static_cast<UINT32>(N - 1), &header_, &value_);
  }
  ScopedHStringRef(const ScopedHStringRef&) = delete;
  ScopedHStringRef& operator=(const ScopedHStringRef&) = delete;

  HRESULT status() const { return hr_; }
  HSTRING get() const { return value_; }

 private:
  HRESULT hr_ = E_FAIL;
  HSTRING_HEADER header_{};
  HSTRING value_ = nullptr;
};

class ScopedHString {
 public:
  ScopedHString() = default;
  ~ScopedHString() { Reset(); }
  ScopedHString(const ScopedHString&) = delete;
  ScopedHString& operator=(const ScopedHString&) = delete;

  HSTRING* Receive() {
    Reset();
    return &value_;
  }

  void Reset() {
    if (value_ != nullptr) {
      ::WindowsDeleteString(value_);
      value_ = nullptr;
    }
  }

  std::string ToUtf8() const {
    if (value_ == nullptr) {
      return {};
    }
    UINT32 wide_len = 0;
    const wchar_t* wide = ::WindowsGetStringRawBuffer(value_, &wide_len);
    if (wide == nullptr || wide_len == 0) {
      return {};
    }
    const int utf8_len = ::WideCharToMultiByte(
        CP_UTF8, 0, wide, static_cast<int>(wide_len), nullptr, 0, nullptr,
        nullptr);
    if (utf8_len <= 0) {
      return {};
    }
    std::string out(static_cast<size_t>(utf8_len), '\0');
    ::WideCharToMultiByte(
        CP_UTF8, 0, wide, static_cast<int>(wide_len), &out[0], utf8_len,
        nullptr, nullptr);
    return out;
  }

 private:
  HSTRING value_ = nullptr;
};

class ScopedServiceHandle {
 public:
  explicit ScopedServiceHandle(SC_HANDLE handle = nullptr) : handle_(handle) {}
  ~ScopedServiceHandle() { Reset(); }
  ScopedServiceHandle(const ScopedServiceHandle&) = delete;
  ScopedServiceHandle& operator=(const ScopedServiceHandle&) = delete;

  SC_HANDLE get() const { return handle_; }
  explicit operator bool() const { return handle_ != nullptr; }

  void Reset(SC_HANDLE handle = nullptr) {
    if (handle_ != nullptr) {
      ::CloseServiceHandle(handle_);
    }
    handle_ = handle;
  }

 private:
  SC_HANDLE handle_ = nullptr;
};

std::string WideToUtf8(const wchar_t* wide) {
  if (wide == nullptr || *wide == L'\0') {
    return {};
  }
  const int utf8_len = ::WideCharToMultiByte(
      CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
  if (utf8_len <= 1) {
    return {};
  }
  std::string out(static_cast<size_t>(utf8_len - 1), '\0');
  ::WideCharToMultiByte(
      CP_UTF8, 0, wide, -1, &out[0], utf8_len, nullptr, nullptr);
  return out;
}

std::string FormatWin32Error(uint32_t code, const std::string& context) {
  wchar_t* msg_buf = nullptr;
  const DWORD len = ::FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, static_cast<DWORD>(code),
      MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      reinterpret_cast<LPWSTR>(&msg_buf), 0, nullptr);
  std::string details;
  if (len > 0 && msg_buf != nullptr) {
    details = WideToUtf8(msg_buf);
    while (!details.empty() &&
           (details.back() == '\r' || details.back() == '\n' ||
            details.back() == ' ')) {
      details.pop_back();
    }
  }
  if (msg_buf != nullptr) {
    ::LocalFree(msg_buf);
  }
  char code_buf[32]{};
  std::snprintf(code_buf, sizeof(code_buf), " (win32=%u)", code);
  if (details.empty()) {
    return context + code_buf;
  }
  return context + ": " + details + code_buf;
}

std::string FormatHResultError(HRESULT hr, const std::string& context) {
  char buf[32]{};
  std::snprintf(buf, sizeof(buf), " (hr=0x%08X)", static_cast<unsigned int>(hr));
  return context + buf;
}

std::string BandToString(NetOps::TetheringWiFiBand band) {
  switch (band) {
    case NetOps::TetheringWiFiBand_TwoPointFourGigahertz:
      return "TwoPointFourGigahertz";
    case NetOps::TetheringWiFiBand_FiveGigahertz:
      return "FiveGigahertz";
    case NetOps::TetheringWiFiBand_SixGigahertz:
      return "SixGigahertz";
    case NetOps::TetheringWiFiBand_Auto:
    default:
      return "Auto";
  }
}

IcsTetheringState MapTetheringState(NetOps::TetheringOperationalState state) {
  switch (state) {
    case NetOps::TetheringOperationalState_On:
      return IcsTetheringState::kOn;
    case NetOps::TetheringOperationalState_Off:
      return IcsTetheringState::kOff;
    case NetOps::TetheringOperationalState_InTransition:
      return IcsTetheringState::kInTransition;
    case NetOps::TetheringOperationalState_Unknown:
    default:
      return IcsTetheringState::kUnknown;
  }
}

void EmitProgress(const IcsProgressCallback& cb, const char* step) {
  if (cb) {
    cb(step);
  }
}

IcsRepairResult MakeFailure(const std::string& step,
                            const std::string& error,
                            const std::string& hotspot_state = "Unknown") {
  IcsRepairResult result;
  result.ok = false;
  result.services_recovered = false;
  result.hotspot_state = hotspot_state;
  result.step = step;
  result.error = error;
  return result;
}

std::string ServiceLabel(const wchar_t* service_name) {
  return WideToUtf8(service_name);
}

void BestEffortStartIfStopped(IIcsSystemOps* ops, const wchar_t* service_name) {
  const IcsServiceStatus status = ops->QueryService(service_name);
  if (status.state == IcsServiceQueryState::kStopped) {
    ops->StartServiceByName(service_name);
  }
}

IcsServiceOpResult StopServiceWithTimeout(IIcsSystemOps* ops,
                                          const wchar_t* service_name,
                                          const IcsRepairOptions& options) {
  const int poll_ms = (std::max)(25, options.poll_interval_ms);
  const int64_t deadline =
      ops->NowMs() + static_cast<int64_t>((std::max)(500, options.stop_timeout_ms));
  const std::string label = ServiceLabel(service_name);
  bool stop_requested = false;

  while (true) {
    const IcsServiceStatus status = ops->QueryService(service_name);
    if (status.state == IcsServiceQueryState::kQueryFailed) {
      return {false, status.win32_error,
              "Failed to query service " + label};
    }
    if (status.state == IcsServiceQueryState::kNotInstalled) {
      return {false, status.win32_error,
              "Required service " + label + " is not installed"};
    }
    if (status.state == IcsServiceQueryState::kStopped) {
      return {true, 0, {}};
    }

    if ((status.state == IcsServiceQueryState::kRunning ||
         status.state == IcsServiceQueryState::kOtherPending) &&
        !stop_requested) {
      const IcsServiceOpResult stop_res = ops->StopService(service_name);
      if (!stop_res.ok) {
        return {false, stop_res.win32_error,
                stop_res.error.empty()
                    ? ("Failed to stop service " + label)
                    : stop_res.error};
      }
      stop_requested = true;
    }

    if (ops->NowMs() >= deadline) {
      const std::string detail =
          status.state == IcsServiceQueryState::kStopPending
              ? (label + " timed out in StopPending (terminated kill avoided)")
              : (label + " did not stop within timeout");
      return {false, 0, detail};
    }

    ops->SleepMs(poll_ms);
  }
}

IcsServiceOpResult StartServiceWithTimeout(IIcsSystemOps* ops,
                                           const wchar_t* service_name,
                                           const char* wait_step,
                                           const IcsRepairOptions& options,
                                           const IcsProgressCallback& on_progress) {
  const int poll_ms = (std::max)(25, options.poll_interval_ms);
  const int64_t deadline =
      ops->NowMs() + static_cast<int64_t>((std::max)(500, options.start_timeout_ms));
  const std::string label = ServiceLabel(service_name);
  bool start_requested = false;
  bool wait_emitted = false;

  while (true) {
    const IcsServiceStatus status = ops->QueryService(service_name);
    if (status.state == IcsServiceQueryState::kQueryFailed) {
      return {false, status.win32_error,
              "Failed to query service " + label};
    }
    if (status.state == IcsServiceQueryState::kNotInstalled) {
      return {false, status.win32_error,
              "Required service " + label + " is not installed"};
    }
    if (status.state == IcsServiceQueryState::kRunning) {
      return {true, 0, {}};
    }

    if (status.state == IcsServiceQueryState::kStopped && !start_requested) {
      const IcsServiceOpResult start_res = ops->StartServiceByName(service_name);
      if (!start_res.ok) {
        return {false, start_res.win32_error,
                start_res.error.empty()
                    ? ("Failed to start service " + label)
                    : start_res.error};
      }
      start_requested = true;
      if (!wait_emitted) {
        EmitProgress(on_progress, wait_step);
        wait_emitted = true;
      }
    } else if (!wait_emitted) {
      EmitProgress(on_progress, wait_step);
      wait_emitted = true;
    }

    if (ops->NowMs() >= deadline) {
      return {false, 0, label + " failed to reach Running state before timeout"};
    }

    ops->SleepMs(poll_ms);
  }
}

IcsHotspotSnapshot WaitHotspotSettle(IIcsSystemOps* ops,
                                     const IcsRepairOptions& options) {
  const int poll_ms = (std::max)(25, options.poll_interval_ms);
  const int64_t deadline =
      ops->NowMs() + static_cast<int64_t>((std::max)(500, options.stable_timeout_ms));

  IcsHotspotSnapshot latest = ops->ReadHotspotSnapshot();
  while (true) {
    const bool settled =
        latest.query_ok &&
        (latest.state == IcsTetheringState::kOn ||
         latest.state == IcsTetheringState::kOff ||
         latest.state == IcsTetheringState::kNoProfile);
    if (settled || ops->NowMs() >= deadline) {
      return latest;
    }
    ops->SleepMs(poll_ms);
    latest = ops->ReadHotspotSnapshot();
  }
}

class Win32IcsSystemOps final : public IIcsSystemOps {
 public:
  IcsHotspotSnapshot ReadHotspotSnapshot() override {
    IcsHotspotSnapshot snapshot;

    RoInitGuard ro_init(RO_INIT_MULTITHREADED);
    if (!ro_init.IsUsable()) {
      snapshot.error =
          FormatHResultError(ro_init.status(), "RoInitialize failed");
      return snapshot;
    }

    ScopedHStringRef net_info_class(
        RuntimeClass_Windows_Networking_Connectivity_NetworkInformation);
    if (FAILED(net_info_class.status())) {
      snapshot.error = FormatHResultError(
          net_info_class.status(), "Create NetworkInformation HSTRING failed");
      return snapshot;
    }

    ComPtr<NetConn::INetworkInformationStatics> net_info;
    HRESULT hr = ::RoGetActivationFactory(
        net_info_class.get(),
        IID_PPV_ARGS(&net_info));
    if (FAILED(hr) || !net_info) {
      snapshot.error = FormatHResultError(
          hr, "RoGetActivationFactory(NetworkInformation) failed");
      return snapshot;
    }

    ComPtr<NetConn::IConnectionProfile> profile;
    hr = net_info->GetInternetConnectionProfile(&profile);
    if (FAILED(hr)) {
      snapshot.error = FormatHResultError(
          hr, "GetInternetConnectionProfile failed");
      return snapshot;
    }

    if (!profile) {
      snapshot.query_ok = true;
      snapshot.state = IcsTetheringState::kNoProfile;
      snapshot.ssid = "Offline / No Profile";
      snapshot.band = "Auto";
      snapshot.max_clients = 8;
      snapshot.client_count = 0;
      return snapshot;
    }

    ScopedHStringRef tethering_class(
        RuntimeClass_Windows_Networking_NetworkOperators_NetworkOperatorTetheringManager);
    if (FAILED(tethering_class.status())) {
      snapshot.error = FormatHResultError(
          tethering_class.status(),
          "Create NetworkOperatorTetheringManager HSTRING failed");
      return snapshot;
    }

    ComPtr<NetOps::INetworkOperatorTetheringManagerStatics2> statics2;
    hr = ::RoGetActivationFactory(tethering_class.get(), IID_PPV_ARGS(&statics2));
    if (FAILED(hr) || !statics2) {
      snapshot.error = FormatHResultError(
          hr, "RoGetActivationFactory(TetheringManagerStatics2) failed");
      return snapshot;
    }

    ComPtr<NetOps::INetworkOperatorTetheringManager> manager;
    hr = statics2->CreateFromConnectionProfile(profile.Get(), &manager);
    if (FAILED(hr) || !manager) {
      snapshot.error = FormatHResultError(
          hr, "CreateFromConnectionProfile failed");
      return snapshot;
    }

    NetOps::TetheringOperationalState op_state =
        NetOps::TetheringOperationalState_Unknown;
    hr = manager->get_TetheringOperationalState(&op_state);
    if (FAILED(hr)) {
      snapshot.error = FormatHResultError(
          hr, "get_TetheringOperationalState failed");
      return snapshot;
    }

    UINT32 max_clients = 8;
    if (SUCCEEDED(manager->get_MaxClientCount(&max_clients))) {
      snapshot.max_clients = max_clients;
    }

    UINT32 client_count = 0;
    if (SUCCEEDED(manager->get_ClientCount(&client_count))) {
      snapshot.client_count = client_count;
    }

    ComPtr<NetOps::INetworkOperatorTetheringAccessPointConfiguration> ap_config;
    if (SUCCEEDED(manager->GetCurrentAccessPointConfiguration(&ap_config)) &&
        ap_config) {
      ScopedHString ssid_hstr;
      if (SUCCEEDED(ap_config->get_Ssid(ssid_hstr.Receive()))) {
        snapshot.ssid = ssid_hstr.ToUtf8();
      }
      ScopedHString pass_hstr;
      if (SUCCEEDED(ap_config->get_Passphrase(pass_hstr.Receive()))) {
        snapshot.passphrase = pass_hstr.ToUtf8();
      }

      ComPtr<NetOps::INetworkOperatorTetheringAccessPointConfiguration2>
          ap_config2;
      if (SUCCEEDED(ap_config.As(&ap_config2)) && ap_config2) {
        NetOps::TetheringWiFiBand band = NetOps::TetheringWiFiBand_Auto;
        if (SUCCEEDED(ap_config2->get_Band(&band))) {
          snapshot.band = BandToString(band);
        }
      }
    }

    snapshot.query_ok = true;
    snapshot.state = MapTetheringState(op_state);
    return snapshot;
  }

  IcsServiceStatus QueryService(const wchar_t* service_name) override {
    IcsServiceStatus result;
    ScopedServiceHandle scm(
        ::OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT));
    if (!scm) {
      result.win32_error = ::GetLastError();
      return result;
    }

    ScopedServiceHandle svc(
        ::OpenServiceW(scm.get(), service_name, SERVICE_QUERY_STATUS));
    if (!svc) {
      const DWORD err = ::GetLastError();
      result.win32_error = err;
      result.state = (err == ERROR_SERVICE_DOES_NOT_EXIST)
                         ? IcsServiceQueryState::kNotInstalled
                         : IcsServiceQueryState::kQueryFailed;
      return result;
    }

    SERVICE_STATUS_PROCESS ssp{};
    DWORD bytes_needed = 0;
    if (!::QueryServiceStatusEx(svc.get(), SC_STATUS_PROCESS_INFO,
                                reinterpret_cast<LPBYTE>(&ssp), sizeof(ssp),
                                &bytes_needed)) {
      result.win32_error = ::GetLastError();
      result.state = IcsServiceQueryState::kQueryFailed;
      return result;
    }

    result.process_id = ssp.dwProcessId;
    switch (ssp.dwCurrentState) {
      case SERVICE_STOPPED:
        result.state = IcsServiceQueryState::kStopped;
        break;
      case SERVICE_START_PENDING:
        result.state = IcsServiceQueryState::kStartPending;
        break;
      case SERVICE_STOP_PENDING:
        result.state = IcsServiceQueryState::kStopPending;
        break;
      case SERVICE_RUNNING:
        result.state = IcsServiceQueryState::kRunning;
        break;
      default:
        result.state = IcsServiceQueryState::kOtherPending;
        break;
    }
    return result;
  }

  IcsServiceOpResult StopService(const wchar_t* service_name) override {
    ScopedServiceHandle scm(
        ::OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT));
    if (!scm) {
      const DWORD err = ::GetLastError();
      return {false, err, FormatWin32Error(err, "OpenSCManagerW failed")};
    }

    ScopedServiceHandle svc(::OpenServiceW(
        scm.get(), service_name, SERVICE_STOP | SERVICE_QUERY_STATUS));
    if (!svc) {
      const DWORD err = ::GetLastError();
      return {false, err,
              FormatWin32Error(
                  err, "OpenServiceW(" + ServiceLabel(service_name) + ") failed")};
    }

    SERVICE_STATUS ss{};
    if (!::ControlService(svc.get(), SERVICE_CONTROL_STOP, &ss)) {
      const DWORD err = ::GetLastError();
      if (err == ERROR_SERVICE_NOT_ACTIVE) {
        return {true, 0, {}};
      }
      return {false, err,
              FormatWin32Error(
                  err, "ControlService(STOP, " + ServiceLabel(service_name) +
                           ") failed")};
    }
    return {true, 0, {}};
  }

  IcsServiceOpResult StartServiceByName(const wchar_t* service_name) override {
    ScopedServiceHandle scm(
        ::OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT));
    if (!scm) {
      const DWORD err = ::GetLastError();
      return {false, err, FormatWin32Error(err, "OpenSCManagerW failed")};
    }

    ScopedServiceHandle svc(::OpenServiceW(
        scm.get(), service_name, SERVICE_START | SERVICE_QUERY_STATUS));
    if (!svc) {
      const DWORD err = ::GetLastError();
      return {false, err,
              FormatWin32Error(
                  err, "OpenServiceW(" + ServiceLabel(service_name) + ") failed")};
    }

    if (!::StartServiceW(svc.get(), 0, nullptr)) {
      const DWORD err = ::GetLastError();
      if (err == ERROR_SERVICE_ALREADY_RUNNING) {
        return {true, 0, {}};
      }
      return {false, err,
              FormatWin32Error(
                  err, "StartServiceW(" + ServiceLabel(service_name) + ") failed")};
    }
    return {true, 0, {}};
  }

  void SleepMs(int milliseconds) override {
    if (milliseconds > 0) {
      std::this_thread::sleep_for(std::chrono::milliseconds(milliseconds));
    }
  }

  int64_t NowMs() override {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
  }
};

}  // namespace

std::string TetheringStateToString(IcsTetheringState state) {
  switch (state) {
    case IcsTetheringState::kOn:
      return "On";
    case IcsTetheringState::kOff:
      return "Off";
    case IcsTetheringState::kInTransition:
      return "InTransition";
    case IcsTetheringState::kNoProfile:
      return "NoProfile";
    case IcsTetheringState::kUnknown:
    default:
      return "Unknown";
  }
}

IcsRepairResult RunNativeIcsRepair(IIcsSystemOps* ops,
                                     const IcsRepairOptions& options,
                                     const IcsProgressCallback& on_progress) {
  if (ops == nullptr) {
    return MakeFailure("Read Hotspot profile/state",
                       "Null system operations handler");
  }

  // Step 1: Read initial Hotspot profile & state; if currently transitioning,
  // wait briefly for Windows to settle before restarting ICS services.
  EmitProgress(on_progress, "Read Hotspot profile/state");
  IcsHotspotSnapshot initial = ops->ReadHotspotSnapshot();
  if (initial.query_ok && initial.state == IcsTetheringState::kInTransition) {
    initial = WaitHotspotSettle(ops, options);
    if (initial.query_ok && initial.state == IcsTetheringState::kInTransition) {
      return MakeFailure(
          "Read Hotspot profile/state",
          "Hotspot stayed in InTransition; aborted ICS restart safely",
          "InTransition");
    }
  }

  // Step 2: Gracefully stop dependent icssvc first, then SharedAccess via SCM.
  EmitProgress(on_progress, "Stop icssvc");
  const IcsServiceOpResult stop_icssvc =
      StopServiceWithTimeout(ops, L"icssvc", options);
  if (!stop_icssvc.ok) {
    BestEffortStartIfStopped(ops, L"SharedAccess");
    BestEffortStartIfStopped(ops, L"icssvc");
    return MakeFailure("Stop icssvc", stop_icssvc.error);
  }

  EmitProgress(on_progress, "Stop SharedAccess");
  const IcsServiceOpResult stop_shared =
      StopServiceWithTimeout(ops, L"SharedAccess", options);
  if (!stop_shared.ok) {
    // Roll back icssvc cleanly without force-killing SharedAccess.
    BestEffortStartIfStopped(ops, L"icssvc");
    return MakeFailure("Stop SharedAccess", stop_shared.error);
  }

  // Step 3: Start SharedAccess first, wait Running, then start icssvc.
  EmitProgress(on_progress, "Start SharedAccess");
  const IcsServiceOpResult start_shared = StartServiceWithTimeout(
      ops, L"SharedAccess", "Wait SharedAccess Running", options, on_progress);
  if (!start_shared.ok) {
    return MakeFailure("Start SharedAccess", start_shared.error);
  }

  EmitProgress(on_progress, "Start icssvc");
  const IcsServiceOpResult start_icssvc = StartServiceWithTimeout(
      ops, L"icssvc", "Wait icssvc Running", options, on_progress);
  if (!start_icssvc.ok) {
    return MakeFailure("Start icssvc", start_icssvc.error);
  }

  // Step 4: Wait for WinRT Hotspot state to settle without restarting again.
  EmitProgress(on_progress, "Wait Hotspot stable");
  const IcsHotspotSnapshot final_snapshot = WaitHotspotSettle(ops, options);

  // Step 5: Verify both services are Running and inspect final Hotspot state.
  EmitProgress(on_progress, "Verify services Running");
  const IcsServiceStatus shared_verify = ops->QueryService(L"SharedAccess");
  const IcsServiceStatus icssvc_verify = ops->QueryService(L"icssvc");
  const bool services_running =
      shared_verify.state == IcsServiceQueryState::kRunning &&
      icssvc_verify.state == IcsServiceQueryState::kRunning;

  if (!services_running) {
    std::string reason = "Services not Running after recovery (";
    reason += "SharedAccess=" +
              std::to_string(static_cast<int>(shared_verify.state));
    reason += ", icssvc=" +
              std::to_string(static_cast<int>(icssvc_verify.state)) + ")";
    return MakeFailure("Verify services Running", reason);
  }

  IcsRepairResult result;
  result.services_recovered = true;
  if (!final_snapshot.query_ok) {
    result.ok = false;
    result.hotspot_state = "Unknown";
    result.step = "Wait Hotspot stable";
    result.error = final_snapshot.error.empty()
                       ? "Failed to read WinRT Hotspot status after recovery"
                       : final_snapshot.error;
    return result;
  }

  if (final_snapshot.state == IcsTetheringState::kNoProfile) {
    result.ok = true;
    result.hotspot_state = "Off";
    result.has_config = true;
    result.config = final_snapshot;
    if (result.config.ssid.empty()) {
      result.config.ssid = "Offline / No Profile";
    }
    return result;
  }

  result.hotspot_state = TetheringStateToString(final_snapshot.state);
  result.has_config = true;
  result.config = final_snapshot;
  result.ok = (final_snapshot.state == IcsTetheringState::kOn ||
               final_snapshot.state == IcsTetheringState::kOff);
  if (!result.ok) {
    result.step = "Verify services Running";
    result.error =
        "Hotspot state not confirmed (" + result.hotspot_state + ")";
  }
  return result;
}

IcsRepairResult ExecuteLiveWin32IcsRepair(
    const IcsRepairOptions& options,
    const IcsProgressCallback& on_progress) {
  Win32IcsSystemOps live_ops;
  return RunNativeIcsRepair(&live_ops, options, on_progress);
}

}  // namespace ja_wifi
