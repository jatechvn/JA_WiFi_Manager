# Core Business Logic & App Config (`lib/modules`)

## Responsibility & Layout
- `lib/modules/logic.dart`: Public `WifiGuardLogic` `ChangeNotifier` facade + core state, constructor, `initialize()`, and bounded native command runners (`_runNative`, `_runHotspotNative`, `_runBounded`).
- Domain `part` files:
  - `lib/modules/logic_logs_admin_part.dart`: Admin UAC checks, Windows Run-key startup registration, rotating `wifi_guard.log`, and `blocked_session.json` recovery.
  - `lib/modules/logic_device_store_part.dart`: Whitelist CRUD, universal `device_names.json` nicknames, hostname resolution, and JSON import/export.
  - `lib/modules/logic_blacklist_part.dart`: Blacklist CRUD, mutual-exclusion transfers with Whitelist, and immediate dual-layer blocking.
  - `lib/modules/logic_guard_engine_part.dart`: Guard timer loop with re-entrancy coalescing (`_runGuardCheck`), mid-flight cancellation, and idempotent ARP + Firewall rules.
  - `lib/modules/logic_scanner_part.dart`: Coalesced `scanConnectedClients()` pass and IPv4/Reachable-first MAC deduplication.
  - `lib/modules/logic_hotspot_part.dart`: Serialized `_exclusiveHotspot` WinRT Hotspot config/toggle, native Win32/WinRT ICS recovery via `nativeIcsRepair`, DHCP repair, and 30s Hotspot Watchdog auto-heal.
- Supporting modules: `lib/modules/app_config.dart`, `lib/modules/models/wifi_models.dart`, `lib/modules/native/win_ics_service.dart`, `lib/modules/utils/atomic_file_store.dart`, `lib/modules/i18n.dart`, `lib/modules/constants.dart`, `lib/modules/utils.dart`, `lib/modules/logger_config.dart`, `lib/modules/build_info.dart`, `lib/modules/native_bridge.dart`.

## Invariants
- Keep `WifiGuardLogic` methods as virtual instance methods (via `mixin` parts), not static extensions, so test subclasses can override them.
- Preserve exact PowerShell substrings tested in `test/blacklist_enforcement_test.dart`, `test/hotspot_operations_test.dart`, and `test/stability_improvements_test.dart`.
- Always verify changes with `flutter analyze` and `flutter test`.
