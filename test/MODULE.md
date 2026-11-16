# Automated Test Suite (`test/`)

## Test Groups
- **Logic, Blacklist & Stability**: `test/blacklist_test.dart`, `test/blacklist_enforcement_test.dart`, `test/hotspot_operations_test.dart`, `test/ics_progress_banner_test.dart`, `test/ota_update_service_test.dart`, `test/stability_improvements_test.dart`, `test/system_language_test.dart`, `test/windows_app_identity_test.dart`.
- **Power & Frame Gating**: `test/app_power_manager_test.dart`, `test/app_ticker_gate_test.dart`, `test/power_frame_policy_test.dart`, `test/hidden_ui_updates_test.dart`, `test/glass_animation_resume_test.dart`, `test/glass_marquee_session_test.dart`, `test/settings_power_options_test.dart`.
- **UI & Widget Tests**: `test/bento_widgets_test.dart`, `test/monitor_tab_test.dart`, `test/remade_tabs_test.dart`, `test/widget_test.dart`.
- **Native Harnesses**: `test/native/ics_service_repair_test.cpp` (mocked Win32 SCM / WinRT ICS recovery scenarios) and `test/native/single_instance_test.cpp`.

## Commands
- `flutter test`
- Compile & execute `test/native/ics_service_repair_test.cpp` with MSVC (`cl.exe /nologo /std:c++17 /W4 /WX /EHsc /D_HAS_EXCEPTIONS=0`)
