# Reusable UI Widgets (`lib/modules/ui/widgets`)

## Contents
- Monitor & Hotspot widgets: `lib/modules/ui/widgets/monitor_hotspot_banner.dart`, `lib/modules/ui/widgets/hotspot_operation_progress_banner.dart`, `lib/modules/ui/widgets/monitor_kpi_row.dart`, `lib/modules/ui/widgets/monitor_bento_device_card.dart`, `lib/modules/ui/widgets/monitor_compact_device_table.dart`.
- Settings & OTA widgets: `lib/modules/ui/widgets/power_optimizer_card.dart`, `lib/modules/ui/widgets/ota_settings_card.dart`, `lib/modules/ui/widgets/ota_settings_form.dart`, `lib/modules/ui/widgets/glass_update_dialog.dart`.
- Power-aware & animation widgets: `lib/modules/ui/widgets/visible_ui_listener.dart`, `lib/modules/ui/widgets/app_ticker_gate.dart`, `lib/modules/ui/widgets/glass_marquee.dart`, `lib/modules/ui/widgets/glass_power_widgets.dart`.

## Invariants
- Preserve `Key(...)` identifiers (`monitor-hotspot-fix-ics`, `monitor-hotspot-config`, `monitor-hotspot-toggle`) relied upon by widget tests in `test/monitor_tab_test.dart`.
- Before triggering `exit(0)` in `glass_update_dialog.dart`, always invoke `trayManager.destroy()` and caller `onBeforeExit` cleanup so no ghost tray icon persists on Windows.
