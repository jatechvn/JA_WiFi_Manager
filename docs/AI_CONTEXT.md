# AI Context & Navigation Map — JA WiFi Hotspot Guard

This document is the primary architecture, ownership, and navigation entrypoint for AI agents and maintainers.
For hard project rules and mandatory verification commands, read [AGENTS.md](../AGENTS.md).
For functional product specification, read [USERGUIDE.md](../USERGUIDE.md) and [README.md](../README.md).
For the latest verified engineering state and open runtime checks, read [AI_HANDOFF.md](AI_HANDOFF.md).

---

## 1. Entrypoints & Module Ownership

| Directory / File | Owner / Responsibility | Key Symbols & Entrypoints |
| :--- | :--- | :--- |
| `lib/main.dart` | Application startup, CLI args (`-debug`, `--minimized`), `PowerWidgetsBinding`, single-instance elevation/window setup | `main()` |
| `lib/modules/` | Core state coordinator, config, i18n, logging, platform bridge | `WifiGuardLogic` in `lib/modules/logic.dart`, `AppConfig` in `lib/modules/app_config.dart`, `AppStrings` in `lib/modules/i18n.dart`, `lib/modules/constants.dart`, `lib/modules/utils.dart`, `lib/modules/build_info.dart`, `lib/modules/logger_config.dart`, `lib/modules/native_bridge.dart` |
| `lib/modules/models/` | Domain models decoupled from business logic | `WhitelistEntry`, `BlacklistEntry`, `ClientDevice`, `HotspotConfig` in `lib/modules/models/wifi_models.dart` |
| `lib/modules/services/` | Power/GPU gating coordinator & LAN OTA updater | `AppPowerManager` (`lib/modules/services/app_power_manager.dart`), `PowerWidgetsBinding` (`lib/modules/services/power_widgets_binding.dart`), `OtaUpdateService` (`lib/modules/services/ota_update_service.dart`), `OtaUpdateConfig` (`lib/modules/services/ota_update_models.dart`) |
| `lib/modules/utils/` | Atomic `.tmp` -> `.bak` persistence with auto-recovery | `AtomicFileStore` in `lib/modules/utils/atomic_file_store.dart` |
| `lib/modules/native/` | OS-specific elevation, ARP/Firewall native execution wrappers, Win32 ICS channel | `WindowsNativeEngine` (`lib/modules/native/win_core.dart`), `WinIcsNativeService` (`lib/modules/native/win_ics_service.dart`), `lib/modules/native/mac_core.dart`, `lib/modules/native/linux_core.dart` |
| `lib/modules/ui/` | Fluent Bento Glassmorphic tabs, navigation shell, themes | `MainWindow` (`lib/modules/ui/main_window.dart`), `MonitorTab` (`lib/modules/ui/monitor_tab.dart`), `WhitelistTab` (`lib/modules/ui/whitelist_tab.dart`), `BlacklistTab` (`lib/modules/ui/blacklist_tab.dart`), `HotspotTab` (`lib/modules/ui/hotspot_tab.dart`), `ConsoleTab` (`lib/modules/ui/console_tab.dart`), `SettingsTab` (`lib/modules/ui/settings_tab.dart`), `Sidebar` (`lib/modules/ui/sidebar.dart`), `HeaderBar` (`lib/modules/ui/header_bar.dart`), `lib/modules/ui/bento_widgets.dart`, `lib/modules/ui/dialogs.dart`, `lib/modules/ui/styles.dart`, `lib/modules/ui/styles_win10.dart`, `lib/modules/ui/styles_win11.dart` |
| `lib/modules/ui/widgets/` | Reusable monitor, settings, OTA, and power-gated animated widgets | `MonitorHotspotQuickControlBanner` (`lib/modules/ui/widgets/monitor_hotspot_banner.dart`), `HotspotOperationProgressBanner` (`lib/modules/ui/widgets/hotspot_operation_progress_banner.dart`), `MonitorBentoKpiRow` (`lib/modules/ui/widgets/monitor_kpi_row.dart`), `MonitorBentoDeviceCard` (`lib/modules/ui/widgets/monitor_bento_device_card.dart`), `MonitorCompactDeviceTable` (`lib/modules/ui/widgets/monitor_compact_device_table.dart`), `PowerOptimizerCard` (`lib/modules/ui/widgets/power_optimizer_card.dart`), `OtaSettingsCard` (`lib/modules/ui/widgets/ota_settings_card.dart`), `OtaConfigFormFields` (`lib/modules/ui/widgets/ota_settings_form.dart`), `glass_update_dialog` (`lib/modules/ui/widgets/glass_update_dialog.dart`), `VisibleUiListener` (`lib/modules/ui/widgets/visible_ui_listener.dart`), `AppTickerGate` (`lib/modules/ui/widgets/app_ticker_gate.dart`), `GlassMarquee` (`lib/modules/ui/widgets/glass_marquee.dart`), `GlassPowerWidgets` (`lib/modules/ui/widgets/glass_power_widgets.dart`) |
| `windows/runner/` | Native Win32 runner, UAC elevation manifest, single-instance mutex, DWM Acrylic/Mica theming, Win32 SCM + WinRT ICS repair channel | `windows/runner/main.cpp`, `windows/runner/single_instance.h`, `windows/runner/flutter_window.cpp`, `windows/runner/flutter_window.h`, `windows/runner/ics_service_repair.cpp`, `windows/runner/ics_service_repair.h`, `windows/runner/ics_repair_channel.cpp`, `windows/runner/ics_repair_channel.h`, `windows/runner/win32_window.cpp`, `windows/runner/win32_window.h`, `windows/runner/theme_win10.cpp`, `windows/runner/theme_win10.h`, `windows/runner/theme_win11.cpp`, `windows/runner/theme_win11.h`, `windows/runner/utils.cpp`, `windows/runner/utils.h`, `windows/runner/resource.h` |
| `windows/flutter/` | Generated Flutter plugin registrant for Windows desktop builds | `windows/flutter/generated_plugin_registrant.h` |
| `test/` | Dart unit & Flutter widget test suite (18 test files) | See `test/MODULE.md` |
| `test/native/` | Win32 C++ ICS repair & single-instance mutex tests | `test/native/ics_service_repair_test.cpp`, `test/native/single_instance_test.cpp` |
| `scripts/` & Root | Windows GPU/Profile probe scripts and clean uninstaller | `scripts/launch_profile_probe.ps1`, `scripts/capture_profile_probe.ps1`, `scripts/measure_app_power.ps1`, `uninstall.ps1` |

---

## 2. Architecture & Data Flow Highlights

1. **State Management (`ChangeNotifier` + `part` Modularity)**:
   - `lib/modules/logic.dart` is the public facade exporting `lib/modules/models/wifi_models.dart` and combining 6 domain parts: `lib/modules/logic_logs_admin_part.dart`, `lib/modules/logic_device_store_part.dart`, `lib/modules/logic_blacklist_part.dart`, `lib/modules/logic_guard_engine_part.dart`, `lib/modules/logic_scanner_part.dart`, `lib/modules/logic_hotspot_part.dart`.
   - Do not convert `lib/modules/logic.dart` methods into static Dart `extension`s because test doubles (such as in `test/monitor_tab_test.dart`) subclass `WifiGuardLogic` and `@override` virtual methods (`setHotspotState`, `repairIcsService`, `icsRepairError`).
2. **Guard Loop, Blacklist & Persistent Session State**:
   - `_runGuardCheck` and `scanConnectedClients` enforce re-entrancy coalescing so overlapping timers/refreshes cannot pile up PowerShell processes; all native commands run with bounded timeouts.
   - Blacklist enforcement combines Layer-2 ARP poisoning (`Set`/`New-NetNeighbor` -> `00-00-00-00-00-01`) and Layer-3 idempotent Windows Firewall rules (`WiFiGuard_*_IN` tagged with `Description="MAC=..."`).
   - `_blockedIpToRealMac` persists to `blocked_session.json` so real MAC mapping survives console `clearLogs()`, log pruning, and app restarts.
3. **3-Tier Power & GPU Optimizer**:
   - `PowerWidgetsBinding` (`lib/modules/services/power_widgets_binding.dart`) + `AppPowerManager` (`lib/modules/services/app_power_manager.dart`) gate scheduler frames when hidden/minimized/unfocused while allowing background Guard & Hotspot timers to run uninterrupted.
   - `VisibleUiListener` coalesces hidden `notifyListeners()` notifications to a single UI rebuild upon window restoration.
4. **Atomic Persistence & Protected Portable Files**:
   - `AtomicFileStore` writes `.tmp` -> backs up valid primary to `.bak` -> renames atomically, auto-healing on 0-byte or truncated files.
   - Never wipe or overwrite user runtime files (`config.ini`, `whitelist.json`, `blacklist.json`, `device_names.json`, `blocked_session.json`, `update_config.json`, `wifi_guard.log`) in cleanups or OTA robocopy passes.

---

## 3. Verification Commands

Run sequentially from repository root:
1. `flutter analyze` — Static analysis (must report 0 issues).
2. `dart format .` — Code formatting.
3. `flutter test` — Full Dart/Flutter unit & widget suite (104 tests).
4. Compile & execute `test/native/ics_service_repair_test.cpp` with MSVC `cl.exe /nologo /std:c++17 /W4 /WX /EHsc /D_HAS_EXCEPTIONS=0` — Mocked Win32 SCM & WinRT ICS recovery scenarios.
