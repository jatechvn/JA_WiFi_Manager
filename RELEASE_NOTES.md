TAG=v1.2.1
TITLE=JA WiFi Hotspot Guard v1.2.1 — Tối ưu hóa Năng lượng, Giảm 100% Tải GPU Inactive & Chế độ Ngủ Rảnh Tay
BODY=
## JA WiFi Hotspot Guard v1.2.1 — Tối ưu hóa Năng lượng, Giảm 100% Tải GPU Inactive & Chế độ Ngủ Rảnh Tay

- **Tối ưu hóa điện năng toàn diện (Power & GPU Optimizer):** Triệt tiêu 100% draw calls dư thừa khi cửa sổ mất focus (Inactive), thu nhỏ (Minimized) hoặc khi người dùng không thao tác, giải phóng tài nguyên CPU/GPU cho hệ thống.
- **Trung tâm điều phối tập trung AppPowerManager:** Quản lý vòng đời trạng thái cửa sổ dưới dạng Single Source of Truth, đồng bộ các luồng Notifier chuyên biệt cho đồ họa nền, chỉ báo và chữ cuộn.
- **Chế độ ngủ rảnh tay (Idle Sleep Mode):** Tự động đưa hiệu ứng đồ họa nặng vào trạng thái ngủ sau 12 giây rảnh tay (tùy chọn 12s, 30s, 60s trong tab Cài đặt), đánh thức tức thì khi rê chuột hoặc nhấn phím.
- **Bảo toàn hướng chuyển động (Direction Preservation):** Loại bỏ hiện tượng giật ngược chiều đột ngột khi kích hoạt lại animation dạng lặp tiến lùi (`WaveIndicator`, `MeshOrb`).
- **Session Epoch Guard & Đóng băng Offset:** Bảo toàn chính xác vị trí cuộn của `GlassMarquee` khi đóng băng, triệt tiêu hoàn toàn các callback ma từ Timer/Future cũ.
- **Cổng ngắt Ticker UI (`AppTickerGate`):** Tự động vô hiệu hóa toàn bộ TickerMode trên cây giao diện khi cửa sổ không active, đảm bảo 0 frame vẽ dư thừa.
- **Sửa lỗi Focus Win32 Native:** Khắc phục lỗi cướp focus trong `win32_window.cpp` khi nhận thông điệp `WM_ACTIVATE`.
- **Bảo toàn 100% tác vụ bảo mật chạy ngầm:** Vòng lặp bảo vệ Wi-Fi Guard (`_guardLoopTimer`) và tiến trình kiểm tra cập nhật LAN OTA tiếp tục hoạt động liên tục 100% không bị ảnh hưởng.

### Cài đặt
Giải nén toàn bộ `JA_WiFi_Manager_v1.2.1_Windows_x64.zip` và chạy `ja_wifi_manager.exe`. Xem `USERGUIDE.md` trong gói để biết thêm chi tiết.
