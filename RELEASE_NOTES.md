TAG=v1.2.0
TITLE=JA WiFi Hotspot Guard v1.2.0 — Tính năng Blacklist, Ghi nhớ tên thiết bị vĩnh viễn & Bảo vệ cấu hình OTA Zero-Reset
BODY=
## JA WiFi Hotspot Guard v1.2.0 — Tính năng Blacklist, Ghi nhớ tên thiết bị vĩnh viễn & Bảo vệ cấu hình OTA Zero-Reset

- **Tab Blacklist (Danh sách chặn chuyên biệt):** Giao diện Bento Glassmorphic hoàn chỉnh với thẻ KPI, thanh dock lọc thông minh, thẻ thiết bị trực quan, hỗ trợ đổi tên inline và thao tác chuyển đổi tương hỗ mượt mà sang Whitelist.
- **Cơ chế cô lập Blacklist kép:** Tự động chặn thiết bị trong Blacklist bằng ARP Poisoning (chỉ điểm MAC giả 00-00-00-00-00-01) kết hợp Windows Firewall Inbound Block thời gian thực.
- **Ghi nhớ tên thiết bị vĩnh viễn (Universal Persistent Renaming):** Toàn bộ các thao tác đổi tên thiết bị ở bất kỳ tab nào đều được lưu vào `device_names.json`, đồng bộ đa chiều và bảo toàn tuyệt đối qua các lần quét mạng hoặc khởi động lại ứng dụng.
- **Bảo vệ cấu hình tuyệt đối khi Update LAN OTA (Zero-Reset Protection):** Quy trình OTA loại trừ hoàn toàn các file cấu hình và cơ sở dữ liệu người dùng (`config.ini`, `whitelist.json`, `blacklist.json`, `device_names.json`, `update_config.json`, `user_preferences.json`, `wifi_guard.log`) với cơ chế Robocopy `/XF` và sao lưu dự phòng tự động trước khi ghi đè bản cập nhật.
- **Bộ nhận diện thương hiệu & Logo mới:** Logo nền trong suốt mới sắc nét, đóng gói đa kích cỡ vào file exe icon và sửa triệt để lỗi icon trên thanh tiêu đề Windows.

### Cài đặt
Giải nén toàn bộ `JA_WiFi_Manager_v1.2.0_Windows_x64.zip` và chạy `ja_wifi_manager.exe`. Xem `USERGUIDE.md` trong gói để biết thêm chi tiết.
