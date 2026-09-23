# 📖 Hướng Dẫn Sử Dụng — JA WiFi Hotspot Guard v1.1.8

Ứng dụng quản trị và bảo vệ điểm phát sóng di động (Windows Mobile Hotspot) chuyên nghiệp với giao diện Bento Glassmorphic hiện đại, cơ chế phòng thủ xâm nhập kép (ARP Poisoning + Windows Firewall) và cập nhật mạng nội bộ LAN Over-The-Air (OTA).

---

## 📦 1. Cài đặt & Khởi chạy

### Cách 1: Sử dụng Bản Portable Trực tiếp (Không cần cài đặt)
1. Tải gói phát hành `JA_WiFi_Manager_v1.1.8_Windows_x64.zip`.
2. Giải nén vào thư mục bất kỳ trên máy tính (ví dụ `D:\Tools\JA_WiFi_Manager\`).
3. Nhấp đúp vào `ja_wifi_manager.exe` để khởi chạy.
   > **Lưu ý:** Ứng dụng sẽ tự động yêu cầu quyền Administrator (UAC). Vui lòng nhấn **Yes** để cho phép ứng dụng can thiệp vào bảng ARP và Windows Firewall nhằm ngăn chặn thiết bị lạ.

### Cách 2: Cài đặt vào Hệ thống với bộ cài chuẩn Windows
1. Giải nén file zip vào một thư mục tạm.
2. Nhấp đúp vào file `install.bat`.
3. Trình cài đặt sẽ:
   - Tự động sao chép ứng dụng vào thư mục `%LOCALAPPDATA%\Programs\JA_WiFi_Manager\`.
   - Tạo shortcut tiện lợi trên **Desktop** và trong **Start Menu**.
   - Hỗ trợ gỡ bỏ hoàn toàn sạch sẽ qua `uninstall.bat` hoặc Control Panel.

---

## 🛡️ 2. Các chức năng chính

### A. Tab Giám sát (Monitor Tab)
- **Bảng KPI tương tác:** Hiển thị tổng số kết nối, số thiết bị đã được duyệt vào Whitelist, và số thiết bị lạ bị chặn. Bạn có thể nhấn trực tiếp vào thẻ KPI để lọc nhanh danh sách.
- **Thanh công cụ lọc & Tìm kiếm:**
  - Ô tìm kiếm tức thì theo tên, địa chỉ IP hoặc MAC.
  - Các chip lọc trạng thái: *Tất cả*, *Đã duyệt*, *Bị chặn*, *Chờ duyệt*.
  - Nút chuyển đổi giao diện linh hoạt giữa dạng **Thẻ Bento** và **Bảng thu gọn (Compact Table)**.
- **Thao tác nhanh trên từng thiết bị:**
  - Nhấn nút **Bảo vệ / Chặn** hoặc **Whitelist** nhanh.
  - Sửa đổi biệt danh (Nickname) hiển thị thân thiện.
  - Sao chép địa chỉ MAC 1-click vào Clipboard.

### B. Tab Danh sách trắng (Whitelist Tab)
- Quản lý các thiết bị tin cậy được phép truy cập Internet qua trạm phát Hotspot.
- **Thêm thiết bị mới:** Nhấn nút `+ Thêm thiết bị`, nhập địa chỉ MAC và đặt biệt danh.
- **Sao lưu & Phục hồi:** Nhập/Xuất danh sách trắng ra file JSON để dễ dàng di chuyển sang máy tính khác.

### C. Tab Điểm phát sóng (Mobile Hotspot Tab)
- Quản lý trạng thái Bật/Tắt của Windows Mobile Hotspot.
- Cấu hình Tên mạng (SSID), Mật khẩu (WPA2-PSK), Băng tần Wi-Fi (Auto / 2.4 GHz / 5.0 GHz) và Giới hạn số lượng máy kết nối.
- **Công cụ sửa lỗi ICS:** Nút *Sửa lỗi ICS (Buộc dừng)* tự động tìm PID của tiến trình `SharedAccess` bị treo, tắt cưỡng chế và khởi động lại dịch vụ chia sẻ mạng của Windows.

### D. Tab Nhật ký (Console Tab)
- Xem luồng log theo thời gian thực với phân loại mã màu (BLOCK, ALLOW, WARN, INFO).
- Hỗ trợ tìm kiếm từ khóa trong log, lọc theo mức độ, bật/tắt Auto Scroll và sao chép toàn bộ log.

### E. Tab Cài đặt & LAN OTA Update (Settings Tab)
- **Tùy chọn hệ thống:** Cấu hình tần suất quét kiểm tra (5s, 10s, 30s), khởi động cùng Windows, thu nhỏ về khay hệ thống (System Tray).
- **Cập nhật nội bộ LAN OTA:** Thiết lập đường dẫn máy chủ chia sẻ mạng (SMB Share `\\Server\Share\JA_WiFi_Manager`) để tự động kiểm tra và nâng cấp phiên bản mới trong mạng LAN mà không cần Internet.

---

## ❓ 3. Khắc phục sự cố thường gặp

1. **Ứng dụng không chặn được thiết bị lạ:**
   - Đảm bảo ứng dụng đang chạy với quyền Administrator (có biểu tượng hoặc nhãn Administrator trên giao diện).
   - Kiểm tra xem công tắc *Guard Engine* ở thanh bên trái (Sidebar) đã được Bật (`ACTIVE`).

2. **Hotspot Windows báo lỗi "We can't set up mobile hotspot":**
   - Chuyển sang tab **Điểm phát sóng (Hotspot)**, nhấn nút **Sửa lỗi ICS** để ứng dụng tự động dọn dẹp tiến trình chia sẻ mạng bị nghẽn.

3. **Giao diện kính mờ trên Windows 10:**
   - Trên Windows 10, ứng dụng tự động tối ưu độ trong suốt và ẩn hộp tiêu đề đen nhằm mang lại trải nghiệm thị giác sạch sẽ nhất.
