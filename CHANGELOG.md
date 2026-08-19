# 📜 CHANGELOG - JA WiFi Hotspot Guard

All notable changes to **JA WiFi Hotspot Guard** will be documented in this file.

---

## [v1.1.6] - 2026-08-14

### 🚀 Major Features & Enhancements
- **🐞 `-debug` Launch Mode:**
  - Added `debug.bat` and a `-debug` CLI flag that switches every visible timestamp (Console tab + internal log file) to full ISO precision.
  - Added a **Debug Badge** in the sidebar, next to the Guard Engine card, showing `DEBUG · v<version> (<build time>)` — build time is read from the compiled `app.so`/executable, not the current clock.
  - Overflowing badge text now uses a smooth **Bounce / Ping-Pong Marquee** (built on `SingleChildScrollView` + `ScrollController.animateTo()`) instead of being cut off with an ellipsis.
- **🎨 Smarter Theme Default:**
  - The Light/Dark toggle no longer cycles through a separate "auto" stop; a fresh install now seeds its starting theme from the current Windows system theme instead of a hardcoded Dark default.

### 🐛 Bug Fixes
- **📡 Duplicate Devices in Monitor:** `Get-NetNeighbor` returns multiple rows per physical device (IPv4 + IPv6 link-local + stale entries); the client list is now deduplicated by MAC address with an IPv4/`Reachable`-priority score.
- **🔑 `-debug` Flag Dropped on Elevation:** the Administrator self-elevation relaunch (`Start-Process -Verb RunAs`) was silently dropping all original CLI arguments; `-debug` (and `--minimized`) are now forwarded through elevation via `-ArgumentList`.
- **🕒 Debug Timestamps Not Visible in UI:** the debug-mode timestamp switch previously only affected the internal file logger; it now also applies to the Console tab's visible log formatter.
- **✂️ Debug Badge Marquee Clipping:** the marquee previously measured text width by hand (`TextPainter`, then `RenderBox`), which could diverge from the real render on displays with non-100% Windows scaling and permanently cut off the tail of the text. Replaced with a `ScrollController`-driven scroll view so Flutter's own layout is the single source of truth.

### 🔧 Chores
- Refactored `main_window.dart` (2700+ lines) into per-widget files (`sidebar.dart`, `header_bar.dart`, `monitor_tab.dart`, `whitelist_tab.dart`, `hotspot_tab.dart`, `console_tab.dart`, `settings_tab.dart`) under `lib/modules/ui/`, following the project's Clean Architecture / single-responsibility rules.
- Moved the `SharedAccess` service-restart call out of the UI layer into `logic.dart`.
- Excluded personal runtime files (`config.ini`, `whitelist.json`, `logs/`, `wifi_guard.log`) from release packaging.

---

## [v1.0.0] - 2026-06-22

- Initial Flutter/Dart Windows desktop release: Mobile Hotspot client monitoring, MAC whitelist, ARP + Firewall auto-block guard engine, transparent Acrylic/Mica window, English/Vietnamese/Chinese UI.
