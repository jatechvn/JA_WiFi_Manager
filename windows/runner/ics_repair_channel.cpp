#include "ics_repair_channel.h"

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstdint>
#include <utility>

namespace ja_wifi {

namespace {

constexpr char kChannelName[] = "ja_wifi_manager/ics_repair";

int ExtractIntArg(const flutter::EncodableMap* args,
                  const char* key,
                  int default_value,
                  int min_value,
                  int max_value) {
  if (args == nullptr) {
    return default_value;
  }
  const auto it = args->find(flutter::EncodableValue(std::string(key)));
  if (it == args->end()) {
    return default_value;
  }
  if (const auto* val32 = std::get_if<int32_t>(&it->second)) {
    return std::clamp(static_cast<int>(*val32), min_value, max_value);
  }
  if (const auto* val64 = std::get_if<int64_t>(&it->second)) {
    const int64_t clamped = std::clamp<int64_t>(*val64, min_value, max_value);
    return static_cast<int>(clamped);
  }
  return default_value;
}

flutter::EncodableValue BuildResultPayload(const IcsRepairResult& res) {
  flutter::EncodableMap payload;
  payload[flutter::EncodableValue(std::string("Ok"))] =
      flutter::EncodableValue(res.ok);
  payload[flutter::EncodableValue(std::string("ServicesRecovered"))] =
      flutter::EncodableValue(res.services_recovered);
  payload[flutter::EncodableValue(std::string("HotspotState"))] =
      flutter::EncodableValue(res.hotspot_state);
  payload[flutter::EncodableValue(std::string("Step"))] =
      flutter::EncodableValue(res.step);
  payload[flutter::EncodableValue(std::string("Error"))] =
      flutter::EncodableValue(res.error);

  if (res.has_config) {
    flutter::EncodableMap cfg;
    cfg[flutter::EncodableValue(std::string("Ssid"))] =
        flutter::EncodableValue(res.config.ssid);
    cfg[flutter::EncodableValue(std::string("Passphrase"))] =
        flutter::EncodableValue(res.config.passphrase);
    cfg[flutter::EncodableValue(std::string("Band"))] =
        flutter::EncodableValue(res.config.band);
    cfg[flutter::EncodableValue(std::string("State"))] =
        flutter::EncodableValue(std::string(
            res.hotspot_state == "On" ? "Enabled" : "Disabled"));
    cfg[flutter::EncodableValue(std::string("MaxClients"))] =
        flutter::EncodableValue(static_cast<int32_t>(res.config.max_clients));
    cfg[flutter::EncodableValue(std::string("ClientCount"))] =
        flutter::EncodableValue(static_cast<int32_t>(res.config.client_count));
    payload[flutter::EncodableValue(std::string("Config"))] =
        flutter::EncodableValue(cfg);
  }

  return flutter::EncodableValue(payload);
}

}  // namespace

IcsRepairChannel::IcsRepairChannel(HWND hwnd, flutter::BinaryMessenger* messenger)
    : hwnd_(hwnd) {
  if (messenger == nullptr) {
    return;
  }
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleMethodCall(call, std::move(result)); });
}

IcsRepairChannel::~IcsRepairChannel() {
  Shutdown();
}

void IcsRepairChannel::Shutdown() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
  }

  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> cancelled;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    shutting_down_ = true;
    hwnd_ = nullptr;
    pending_steps_.clear();
    has_completed_result_ = false;
    cancelled = std::move(pending_result_);
  }

  if (cancelled) {
    cancelled->Error("SHUTDOWN", "Window closed during ICS repair");
  }

  JoinWorkerIfNeeded();
  channel_.reset();
}

void IcsRepairChannel::JoinWorkerIfNeeded() {
  if (worker_.joinable()) {
    worker_.join();
  }
}

void IcsRepairChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() != "repairIcs") {
    result->NotImplemented();
    return;
  }

  IcsRepairOptions options;
  const auto* args =
      std::get_if<flutter::EncodableMap>(call.arguments());
  options.stop_timeout_ms =
      ExtractIntArg(args, "stopTimeoutMs", options.stop_timeout_ms, 500, 60000);
  options.start_timeout_ms =
      ExtractIntArg(args, "startTimeoutMs", options.start_timeout_ms, 500, 60000);
  options.stable_timeout_ms = ExtractIntArg(
      args, "stableTimeoutMs", options.stable_timeout_ms, 500, 30000);

  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (shutting_down_) {
      result->Error("SHUTDOWN", "ICS repair channel is shutting down");
      return;
    }
    if (running_) {
      result->Error("BUSY", "ICS repair is already running");
      return;
    }
  }

  // Ensure any previously completed worker thread is joined before reusing.
  JoinWorkerIfNeeded();

  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (shutting_down_) {
      result->Error("SHUTDOWN", "ICS repair channel is shutting down");
      return;
    }
    running_ = true;
    pending_steps_.clear();
    has_completed_result_ = false;
    completed_result_ = IcsRepairResult{};
    pending_result_ = std::move(result);
  }

  worker_ = std::thread([this, options]() {
    const IcsRepairResult repair_result = ExecuteLiveWin32IcsRepair(
        options, [this](const std::string& step) {
          HWND target_hwnd = nullptr;
          {
            std::lock_guard<std::mutex> lock(mutex_);
            if (shutting_down_) {
              return;
            }
            pending_steps_.push_back(step);
            target_hwnd = hwnd_;
          }
          if (target_hwnd != nullptr) {
            ::PostMessageW(target_hwnd, kWmIcsRepairStep, 0, 0);
          }
        });

    HWND target_hwnd = nullptr;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (shutting_down_) {
        return;
      }
      completed_result_ = repair_result;
      has_completed_result_ = true;
      target_hwnd = hwnd_;
    }
    if (target_hwnd != nullptr) {
      ::PostMessageW(target_hwnd, kWmIcsRepairDone, 0, 0);
    }
  });
}

bool IcsRepairChannel::HandleWindowMessage(UINT message) {
  if (message == kWmIcsRepairStep) {
    DrainStepsOnUiThread();
    return true;
  }
  if (message == kWmIcsRepairDone) {
    FinishOnUiThread();
    return true;
  }
  return false;
}

void IcsRepairChannel::DrainStepsOnUiThread() {
  std::vector<std::string> steps;
  bool can_emit = false;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!shutting_down_ && channel_) {
      steps.swap(pending_steps_);
      can_emit = true;
    }
  }
  if (!can_emit) {
    return;
  }
  for (const std::string& step : steps) {
    channel_->InvokeMethod(
        "onProgress", std::make_unique<flutter::EncodableValue>(step));
  }
}

void IcsRepairChannel::FinishOnUiThread() {
  DrainStepsOnUiThread();

  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  IcsRepairResult res;
  bool should_reply = false;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    running_ = false;
    if (!shutting_down_ && has_completed_result_ && pending_result_) {
      res = completed_result_;
      result = std::move(pending_result_);
      has_completed_result_ = false;
      should_reply = true;
    }
  }

  JoinWorkerIfNeeded();

  if (should_reply && result) {
    result->Success(BuildResultPayload(res));
  }
}

}  // namespace ja_wifi
