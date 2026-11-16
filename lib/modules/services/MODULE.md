# Services Layer (`lib/modules/services`)

## Contents
- `lib/modules/services/app_power_manager.dart`: Singleton coordinator for window visibility/focus/minimized state, 12s/30s/60s idle sleep timeout, snapshot revision epoch guards, and 3 animation notifiers (`backgroundAnimationActive`, `indicatorAnimationActive`, `marqueeAnimationActive`).
- `lib/modules/services/power_widgets_binding.dart`: Custom `WidgetsFlutterBinding` enforcing `PowerFramePolicy` to suppress unnecessary GPU frame ticks when minimized, hidden, or unfocused.
- `lib/modules/services/ota_update_service.dart` & `lib/modules/services/ota_update_models.dart`: SemVer parsing, SMB share credential/connection handling, SHA-256 package verification, atomic `update_config.json` storage, and rollback-safe batch updater script generation protecting `config.ini`, `update_config.json`, `whitelist.json`, `blacklist.json`, `device_names.json`, and `blocked_session.json`.
- ICS recovery lives in `lib/modules/native/win_ics_service.dart` (`WinIcsNativeService`) backed by native Win32 SCM + WinRT C++ code in `windows/runner/ics_service_repair.cpp`.

## Verification
- `flutter test test/app_power_manager_test.dart test/power_frame_policy_test.dart test/ota_update_service_test.dart`
