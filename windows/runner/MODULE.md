# Native Windows Runner (`windows/runner`)

## Contents
- `windows/runner/main.cpp` & `windows/runner/single_instance.h`: Requests `SYNCHRONIZE`-only single-instance session-local mutex, forwards CLI flags across elevated launches, and brings existing window handles forward without spawning duplicate instances.
- `windows/runner/flutter_window.cpp`, `windows/runner/flutter_window.h`, `windows/runner/win32_window.cpp`, `windows/runner/win32_window.h`: Flutter Win32 host window, DPI handling, and `WM_ACTIVATE` focus synchronization.
- `windows/runner/ics_service_repair.cpp`, `windows/runner/ics_service_repair.h`, `windows/runner/ics_repair_channel.cpp`, `windows/runner/ics_repair_channel.h`: Native `MethodChannel` (`ja_wifi_manager/ics_repair`) performing bounded `advapi32` SCM graceful stop/start (`icssvc`, `SharedAccess`) and WinRT ABI Hotspot snapshot queries on a worker thread with `PostMessageW` UI-thread step marshaling (zero PowerShell, zero `TerminateProcess`).
- `windows/runner/theme_win10.cpp`, `windows/runner/theme_win10.h`, `windows/runner/theme_win11.cpp`, `windows/runner/theme_win11.h`: DWM composition blur, title bar theming, and rounded-corner adaptation per Windows build.
- `windows/runner/resource.h`, `windows/runner/utils.cpp`, `windows/runner/utils.h`: Embedded resources and Win32 utility helpers (`JA WiFi Hotspot Guard` friendly app identity; keep `OriginalFilename=ja_wifi_manager.exe` unchanged for OTA compatibility).

## Invariants
- Never modify `InternalName` / `OriginalFilename` (`ja_wifi_manager.exe`) or the single-instance mutex name format, as LAN OTA scripts depend on them.
- Verify native runner changes via `flutter build windows --release`, `test/native/ics_service_repair_test.cpp`, and `test/native/single_instance_test.cpp`.
