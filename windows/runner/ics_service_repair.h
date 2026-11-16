#ifndef RUNNER_ICS_SERVICE_REPAIR_H_
#define RUNNER_ICS_SERVICE_REPAIR_H_

#include <cstdint>
#include <functional>
#include <string>

namespace ja_wifi {

enum class IcsTetheringState {
  kUnknown = 0,
  kOn = 1,
  kOff = 2,
  kInTransition = 3,
  kNoProfile = 4,
};

struct IcsHotspotSnapshot {
  bool query_ok = false;
  IcsTetheringState state = IcsTetheringState::kUnknown;
  std::string ssid;
  std::string passphrase;
  std::string band = "Auto";
  uint32_t max_clients = 8;
  uint32_t client_count = 0;
  std::string error;
};

enum class IcsServiceQueryState {
  kQueryFailed = 0,
  kNotInstalled = 1,
  kStopped = 2,
  kStartPending = 3,
  kStopPending = 4,
  kRunning = 5,
  kOtherPending = 6,
};

struct IcsServiceStatus {
  IcsServiceQueryState state = IcsServiceQueryState::kQueryFailed;
  uint32_t win32_error = 0;
  uint32_t process_id = 0;
};

struct IcsServiceOpResult {
  bool ok = false;
  uint32_t win32_error = 0;
  std::string error;
};

struct IcsRepairOptions {
  int stop_timeout_ms = 12000;
  int start_timeout_ms = 15000;
  int stable_timeout_ms = 8000;
  int poll_interval_ms = 250;
};

struct IcsRepairResult {
  bool ok = false;
  bool services_recovered = false;
  std::string hotspot_state = "Unknown";
  std::string step;
  std::string error;
  bool has_config = false;
  IcsHotspotSnapshot config;
};

using IcsProgressCallback = std::function<void(const std::string& step)>;

// Abstract interface over Win32 SCM + WinRT queries so repair state transitions
// can be tested deterministically without touching live OS services.
class IIcsSystemOps {
 public:
  virtual ~IIcsSystemOps() = default;

  virtual IcsHotspotSnapshot ReadHotspotSnapshot() = 0;
  virtual IcsServiceStatus QueryService(const wchar_t* service_name) = 0;
  virtual IcsServiceOpResult StopService(const wchar_t* service_name) = 0;
  virtual IcsServiceOpResult StartServiceByName(const wchar_t* service_name) = 0;
  virtual void SleepMs(int milliseconds) = 0;
  virtual int64_t NowMs() = 0;
};

// Executes the bounded 5-step ICS/Hotspot recovery workflow via SCM control
// requests (no TerminateProcess, no shell spawning).
IcsRepairResult RunNativeIcsRepair(
    IIcsSystemOps* ops,
    const IcsRepairOptions& options = IcsRepairOptions{},
    const IcsProgressCallback& on_progress = nullptr);

// Executes RunNativeIcsRepair against the live Win32 SCM and WinRT APIs.
IcsRepairResult ExecuteLiveWin32IcsRepair(
    const IcsRepairOptions& options = IcsRepairOptions{},
    const IcsProgressCallback& on_progress = nullptr);

std::string TetheringStateToString(IcsTetheringState state);

}  // namespace ja_wifi

#endif  // RUNNER_ICS_SERVICE_REPAIR_H_
