# 📜 CHANGELOG - JA WiFi Hotspot Guard

All notable changes to **JA WiFi Hotspot Guard** will be documented in this file.

## [v1.1.8] - 2026-09-23

### 🚀 Nâng cấp & Tính năng mới
- **Giao diện Bento dày hơn:** thu gọn header, sidebar 220px, và các tab Monitor, Whitelist, Hotspot, Settings để hiện nhiều thiết bị hơn trên một màn hình.
- **Ngôn ngữ và giao diện theo Windows:** lần chạy đầu dùng ngôn ngữ giao diện Windows (`vi` / `zh` / `en`) và chế độ Auto bám sáng/tối của hệ thống.

### 🐛 Sửa lỗi & Tối ưu hóa
- **Thanh tiêu đề Windows 10:** giải quyết triệt để lỗi Windows 10 vẽ hộp chữ đen đặc sau tên ứng dụng trên thanh tiêu đề mica/glass; ẩn caption text native trên Windows 10 để giữ thanh tiêu đề trong suốt hoàn hảo.
- **Đóng cửa sổ không còn treo:** không gọi `destroy()` khi Windows vẫn chặn đóng, và lệnh dọn firewall lúc thoát bị giới hạn 3 giây.
- **Header:** bỏ ô tìm kiếm thừa; tiêu đề tab đi qua `AppStrings`.
- **Thanh lọc Monitor:** tooltip Xóa tìm kiếm, Xem thẻ, Xem bảng đủ Việt / Anh / Trung.

### 📦 Phát hành
- Đồng bộ version 1.1.8+10 trong pubspec.yaml, constants.dart, Runner.rc, ABOUT.txt, README.md, USERGUIDE.md, RELEASE_NOTES.md.
- Đóng gói bản phát hành di động chuẩn Windows x64 kèm mã băm xác thực SHA256SUMS.txt.

## [v1.1.7] - 2026-09-21

### 🚀 Major Features & Enhancements
- **🛠️ Forceful ICS PID-Kill Troubleshooter:**
  - Added `repairIcsService()` using `sc.exe queryex SharedAccess` PID extraction and `taskkill.exe /PID $icsPid /F` to forcefully terminate and restart hung Windows ICS services.
  - Added a dedicated "Sửa lỗi ICS (Buộc dừng)" / "Fix ICS (Kill PID)" button in the Hotspot tab with real-time feedback.
  - Integrated this robust PID-kill logic into `resetSharedAccessService()`, `setHotspotState()`, and `fixHotspotDhcp()`.
- **📦 Standardization with Sample Skill Set (`dart-build-pro` & `flutter-app-blueprint`):**
  - Created standard release packaging script `build.bat` with process termination, asset bundling, `.Release.lnk` shortcut creation, and parent-folder x64 ZIP compression (`dist/JA_WiFi_Manager_v1.1.7_Windows_x64.zip`).
  - Created cross-platform developer scripts `build.sh` and `run.sh`.
  - Added official `LICENSE` file.
  - Added multi-language documentation in `i18n/` (`README.vi.md` and `README.zh-CN.md`) with cross-linking language switcher.
  - Added `lib/modules/build_info.dart` supporting `-debug`, `--debug`, and `-d` CLI flags.

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
