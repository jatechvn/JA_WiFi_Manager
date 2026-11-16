# Platform Native Bridges (`lib/modules/native`)

## Contents
- `lib/modules/native/win_ics_service.dart`: `WinIcsNativeService` client over `MethodChannel('ja_wifi_manager/ics_repair')`, dispatching native Win32 SCM + WinRT ICS repair calls in the Windows runner with live `onProgress` step updates and zero `powershell.exe` spawns.
- `lib/modules/native/win_core.dart`: Windows admin privilege (`IsUserAnAdmin`) probe, self-elevation trigger, and OS process utilities (`WindowsNativeEngine`).
- `lib/modules/native/mac_core.dart` & `lib/modules/native/linux_core.dart`: Platform-specific admin/host stubs for non-Windows environments.

## Invariants
- Never spawn external shells or call process termination APIs from ICS recovery wrappers; keep fallback maps structured so `WifiGuardLogic.repairIcsService` surfaces phase-specific errors.
- Always verify changes alongside native runner code via `flutter test` and `test/native/ics_service_repair_test.cpp`.
