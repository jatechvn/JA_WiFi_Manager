# Desktop UI Tabs & Theme Layer (`lib/modules/ui`)

## Contents
- Navigation shell & chrome: `lib/modules/ui/main_window.dart` (Window/Tray lifecycle, 30s Hotspot Watchdog timer), `lib/modules/ui/sidebar.dart`, `lib/modules/ui/header_bar.dart`.
- Feature tabs: `lib/modules/ui/monitor_tab.dart`, `lib/modules/ui/whitelist_tab.dart`, `lib/modules/ui/blacklist_tab.dart`, `lib/modules/ui/hotspot_tab.dart`, `lib/modules/ui/console_tab.dart`, `lib/modules/ui/settings_tab.dart` (re-exporting `PowerOptimizerCard` and `OtaSettingsCard`).
- Shared design system & modals: `lib/modules/ui/styles.dart`, `lib/modules/ui/styles_win10.dart`, `lib/modules/ui/styles_win11.dart`, `lib/modules/ui/bento_widgets.dart`, `lib/modules/ui/dialogs.dart`.

## Invariants
- Never embed business logic inside `build()`.
- Keep widget nesting shallow (<= 4 levels per `AGENTS.md` Rule 1) and extract sub-widgets into `lib/modules/ui/widgets/`.
- Wrap `ChangeNotifier` listeners in tabs (`MainWindow`, `MonitorTab`, `HotspotTab`) with `VisibleUiListener` so hidden UI updates coalesce without GPU frame churn.
