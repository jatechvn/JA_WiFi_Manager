TAG=v1.3.0
TITLE=JA WiFi Hotspot Guard v1.3.0 — Phục hồi ICS Native C++ Win32/WinRT, Triệt tiêu Treo đơ UI, Thanh tiến trình Bento & Kiến trúc Domain Parts
BODY=
## JA WiFi Hotspot Guard v1.3.0 — Phục hồi ICS Native C++ Win32/WinRT, Triệt tiêu Treo đơ UI, Thanh tiến trình Bento & Kiến trúc Domain Parts

- **Phục hồi ICS Native Win32 SCM + WinRT C++ (Triệt tiêu Symantec SONAR & 0 PowerShell):**
  - Chuyển đổi toàn bộ logic sửa lỗi chia sẻ kết nối Internet (ICS Fix) từ PowerShell (`Stop-Process -Force`) sang mã nguồn C++ Win32 native (`windows/runner/ics_service_repair.cpp`) sử dụng API Windows Service Control Manager (`advapi32`) và WinRT Tethering ABI (`INetworkOperatorTetheringManagerStatics2`).
  - Triệt tiêu 100% cảnh báo giả từ Symantec Endpoint Protection SONAR (`SONAR.Powershell` / `AGR.Terminate`).
  - Tích hợp `IcsRepairChannel` qua MethodChannel `ja_wifi_manager/ics_repair`, thực thi trên worker thread bất đồng bộ và chuyển tiếp tiến trình an toàn về UI thread qua `PostMessageW`.
- **Triệt tiêu hiện tượng treo đơ UI & Thanh tiến trình Bento thời gian thực (Inline Progress Banner):**
  - Cơ chế Interactive Operation Lease (`beginInteractiveOperation` / `endInteractiveOperation`) trên `AppPowerManager` duy trì rendering hiệu ứng/con trỏ ngay cả khi hệ điều hành chập chờn focus trong lúc khởi động lại `SharedAccess`/`icssvc`.
  - Tạm hoãn các tác vụ quét nặng (WMI/ARP) và tuần tự hóa ghi log bất đồng bộ (`_logIoChain`) khi Hotspot đang bận (`isHotspotBusy`), ngăn chặn triệt để hiện tượng khóa UI isolate trên thư mục OneDrive/đám mây.
  - Thêm widget `HotspotOperationProgressBanner` trực quan hóa tiến trình sửa lỗi (5 giai đoạn ICS, 3 giai đoạn DHCP), thanh phần trăm động và bộ đếm giây `00:XXs` hỗ trợ 3 ngôn ngữ (VI/EN/ZH) trên tab Monitor và Hotspot.
- **Tối ưu hóa kiến trúc AI & Phân rã Domain Parts:**
  - Tách `WifiGuardLogic` thành 6 domain parts (`logic_logs_admin_part.dart`, `logic_device_store_part.dart`, `logic_blacklist_part.dart`, `logic_guard_engine_part.dart`, `logic_scanner_part.dart`, `logic_hotspot_part.dart`) bảo toàn nguyên vẹn 100% hợp đồng API và kiểm thử.
  - Phân tách cấu trúc widget giao diện thành các thành phần tái sử dụng độc lập (`power_optimizer_card.dart`, `ota_settings_card.dart`, `ota_settings_form.dart`, `monitor_hotspot_banner.dart`, `monitor_kpi_row.dart`, `monitor_bento_device_card.dart`, `monitor_compact_device_table.dart`).
  - Thiết lập bản đồ điều hướng `docs/AI_CONTEXT.md`, root shim `CLAUDE.md` và 6 file phân định ranh giới `MODULE.md`.
- **Bảo toàn dữ liệu Nguyên tử & Trạng thái phiên chặn (Atomic Persistence & Session Memory):**
  - Tích hợp `AtomicFileStore` với cơ chế ghi trung gian `.tmp` -> `.bak` tự phục hồi khi có sự cố mất điện.
  - Duy trì danh sách thiết bị bị chặn trong phiên qua `blocked_session.json`, không bị mất khi xóa hoặc cắt tỉa log.
  - Bổ sung cơ chế Hotspot Watchdog tự kiểm tra và hàn gắn điểm phát sau 30 giây mất kết nối.
- **Khắc phục xung đột trạng thái vòng đời & Bộ kiểm thử 108 tests:**
  - Giải quyết triệt để race condition giữa `AppLifecycleState.resumed` và sự kiện `onWindowFocus` trong `MainWindow`.
  - Làm sạch các cờ `-NonInteractive -WindowStyle Hidden` ở toàn bộ các hàm Hotspot còn lại.
  - Vượt qua 108/108 bài kiểm tra tự động (`flutter test`).

### Cài đặt
Giải nén toàn bộ `JA_WiFi_Manager_v1.3.0_Windows_x64.zip` và chạy `ja_wifi_manager.exe`. Xem `USERGUIDE.md` trong gói để biết thêm chi tiết.
