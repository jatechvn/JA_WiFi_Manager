# 📜 CHANGELOG - JA WiFi Hotspot Guard

All notable changes to **JA WiFi Hotspot Guard** will be documented in this file.

## [v1.2.1] - 2026-10-02

### 🚀 Nâng cấp & Tính năng mới
- **Tối ưu hóa điện năng & Triệt tiêu 100% tải GPU dư thừa (`flutter-power-optimizer`):**
  - **Single Source of Truth `AppPowerManager`:** Quản lý tập trung toàn diện trạng thái cửa sổ (Focus, Visibility, Idle). Mọi animation và render loop tuân thủ chính sách tiết kiệm năng lượng 4 tầng thống nhất.
  - **Chế độ ngủ rảnh tay (Idle Sleep Mode):** Tự động tạm dừng hoạt ảnh nền nặng (`MeshOrb`) khi người dùng không tương tác sau 12 giây (hỗ trợ tùy chọn 12s, 30s, 60s). Bộ bắt tương tác chuột/phím toàn cục kèm cơ chế throttle 600ms giúp đánh thức giao diện tức thì khi có thao tác.
  - **Bảo toàn hướng chuyển động (Direction Preservation):** Cải tiến `WaveIndicator` và `MeshOrb` tự động theo dõi trạng thái `reverse` khi tạm dừng, tiếp tục đúng chiều chuyển động khi kích hoạt lại mà không bị giật ngược chiều đột ngột.
  - **Session Epoch Guard & Đóng băng Offset:** Tích hợp bộ đếm phiên bản `_sessionEpoch++` và đóng băng vị trí cuộn `jumpTo(currentOffset)` trong `GlassMarquee`, triệt tiêu hoàn toàn callback ma từ Timer/Future và ngăn ngừa trôi chữ cuộn.
  - **Cổng ngắt Ticker UI (`AppTickerGate`):** Tự động ngắt toàn bộ TickerMode của cây giao diện khi cửa sổ bị ẩn, thu nhỏ hoặc mất focus, triệt tiêu 100% continuous draw calls.
  - **Bảo toàn 100% tác vụ bảo mật chạy ngầm:** Vòng lặp bảo vệ Wi-Fi Guard (`_guardLoopTimer`) và tiến trình kiểm tra cập nhật mạng nội bộ LAN OTA tiếp tục chạy độc lập 100% ở chế độ ngầm.
  - **Thẻ cấu hình Power Optimizer trong Settings:** Bổ sung `PowerOptimizerCard` vào tab Cài đặt với công tắc bật/tắt chế độ ngủ rảnh tay và bộ chọn mốc thời gian 12s/30s/60s lưu trữ bền vững trong `config.ini`, hỗ trợ đầy đủ 3 ngôn ngữ (Tiếng Việt, English, 中文).

### 🐛 Sửa lỗi & Tối ưu hóa
- **Khắc phục lỗi cướp Focus Win32 Native:** Xử lý thông điệp `WM_ACTIVATE` trong `windows/runner/win32_window.cpp`, chỉ gọi `SetFocus` khi `LOWORD(wparam) != WA_INACTIVE`, ngăn hệ điều hành vô tình kích hoạt lại render loop khi cửa sổ chuyển sang inactive.
- **Tối ưu hóa UI Refresh Timer:** Tạm dừng bộ định thời quét giao diện `_refreshTimer` khi cửa sổ mất focus hoặc thu nhỏ, giải phóng tải CPU phụ trợ.

### 📦 Phát hành
- Đồng bộ version 1.2.1+12 trong pubspec.yaml, constants.dart, Runner.rc, ABOUT.txt, README.md, USERGUIDE.md, RELEASE_NOTES.md.
- Đóng gói bản phát hành di động chuẩn Windows x64 kèm mã băm xác thực SHA256SUMS.txt.

## [v1.2.0] - 2026-10-01

### 🚀 Nâng cấp & Tính năng mới
- **Tab Blacklist (Danh sách chặn chuyên biệt):** Bổ sung tab quản lý Blacklist theo ngôn ngữ thiết kế Bento Glassmorphic hiện đại, tích hợp thẻ KPI (Total, Active Interceptions, Armed Offline), thanh dock lọc tìm kiếm tức thì, đổi tên inline và nút chuyển đổi tương hỗ nhanh giữa Whitelist và Blacklist.
- **Cơ chế cô lập Blacklist thời gian thực:** Tự động can thiệp cô lập thiết bị thuộc Blacklist ngay khi kết nối bằng cơ chế kép (ARP Poisoning LinkLayer 00-00-00-00-00-01 + Windows Firewall Inbound Block).
- **Ghi nhớ tên thiết bị vĩnh viễn (Universal Persistent Renaming):** Bổ sung file lưu trữ `device_names.json`. Việc đổi tên thiết bị ở bất kỳ vị trí nào trên giao diện (Monitor, Whitelist, Blacklist hay qua Dialog) đều được ghi nhớ vĩnh viễn, đồng bộ đa chiều và bảo toàn tuyệt đối sau khi rescan hay khởi động lại máy.
- **Bảo vệ cấu hình tuyệt đối khi Update LAN OTA (Zero-Reset Protection):** Nâng cấp `OtaUpdateService`, kịch bản cập nhật và bộ cài đặt `install.bat` với bộ lọc loại trừ Robocopy `/XF` và sao lưu an toàn tự động, đảm bảo quá trình cập nhật OTA không bao giờ reset `config.ini`, `whitelist.json`, `blacklist.json`, `device_names.json`, `update_config.json`, `user_preferences.json` hay log hệ thống.
- **Bộ nhận diện Icon & Logo mới:** Thiết kế logo mới nền trong suốt, đóng gói icon exe chuẩn ICO đa độ phân giải và sửa lỗi hiển thị icon trên thanh tiêu đề Windows 10/11.

### 🐛 Sửa lỗi & Tối ưu hóa
- **Loại trừ tương hỗ (Mutual Exclusion):** Đảm bảo một thiết bị không bao giờ cùng lúc nằm trong cả Whitelist và Blacklist; tự động gỡ khỏi danh sách đối lập khi thêm mới.
- **Tối ưu hóa phản hồi giao diện:** Cập nhật trạng thái thiết bị trong bộ nhớ O(1) ngay lập tức khi thêm/xóa danh sách thay vì gọi các lệnh PowerShell quét mạng gây giật lag giao diện.

### 📦 Phát hành
- Đồng bộ version 1.2.0+11 trong pubspec.yaml, constants.dart, Runner.rc, ABOUT.txt, README.md, USERGUIDE.md, RELEASE_NOTES.md.
- Đóng gói bản phát hành di động chuẩn Windows x64 kèm mã băm xác thực SHA256SUMS.txt.

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
