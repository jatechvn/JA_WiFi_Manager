#ifndef RUNNER_ICS_REPAIR_CHANNEL_H_
#define RUNNER_ICS_REPAIR_CHANNEL_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "ics_service_repair.h"

namespace ja_wifi {

constexpr UINT kWmIcsRepairStep = WM_APP + 0x101;
constexpr UINT kWmIcsRepairDone = WM_APP + 0x102;

// Hosts the "ja_wifi_manager/ics_repair" MethodChannel and dispatches live
// repair execution onto a worker thread while marshaling progress events and
// MethodResult completion back onto the Win32 UI thread.
class IcsRepairChannel {
 public:
  IcsRepairChannel(HWND hwnd, flutter::BinaryMessenger* messenger);
  ~IcsRepairChannel();

  IcsRepairChannel(const IcsRepairChannel&) = delete;
  IcsRepairChannel& operator=(const IcsRepairChannel&) = delete;

  // Handles kWmIcsRepairStep and kWmIcsRepairDone posted to |hwnd_|.
  bool HandleWindowMessage(UINT message);

  // Unregisters the MethodCallHandler and joins any active worker before
  // FlutterWindow teardown destroys the messenger/HWND.
  void Shutdown();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void DrainStepsOnUiThread();
  void FinishOnUiThread();
  void JoinWorkerIfNeeded();

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  std::mutex mutex_;
  HWND hwnd_ = nullptr;
  bool shutting_down_ = false;
  bool running_ = false;
  std::vector<std::string> pending_steps_;
  bool has_completed_result_ = false;
  IcsRepairResult completed_result_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
      pending_result_;
  std::thread worker_;
};

}  // namespace ja_wifi

#endif  // RUNNER_ICS_REPAIR_CHANNEL_H_
