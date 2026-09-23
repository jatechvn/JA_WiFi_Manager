<div align="center">

  <img src="../assets/app_icon.ico" width="96" height="96" alt="JA WiFi Hotspot Guard Logo" />

  # 🛡️ JA WiFi Hotspot Guard

  ### *Hệ thống bảo vệ thời gian thực cho Windows Mobile Hotspot*

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Platform](https://img.shields.io/badge/Platform-Windows_10_%7C_11-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://microsoft.com/windows)
  [![Release](https://img.shields.io/badge/Release-v1.1.8-00ADB5?style=for-the-badge&logo=github&logoColor=white)](https://github.com/jatechvn/JA_WiFi_Manager/releases)
  [![License](https://img.shields.io/badge/License-Proprietary-FFB100?style=for-the-badge)](#-giấy-phép--tác-giả)

  <p align="center">
    <a href="../README.md">🇺🇸 English</a> • <b>🇻🇳 Tiếng Việt</b> • <a href="README.zh-CN.md">🇨🇳 中文</a>
  </p>

  <p align="center">
    <b>Giám sát thiết bị kết nối • Quản lý danh sách trắng (Whitelist) • Tự động chặn thiết bị lạ bằng ARP Poisoning + Windows Firewall</b>
  </p>

  ---

</div>

## 📑 Mục lục

- [✨ Tính năng cốt lõi](#-tính-năng-cốt-lõi)
- [🎨 Giao diện & Cá nhân hóa](#-giao-diện--cá-nhân-hóa)
- [📐 Cấu trúc thư mục & Kiến trúc kỹ thuật](#-cấu-trúc-thư-mục--kiến-trúc-kỹ-thuật)
- [🚀 Hướng dẫn bắt đầu nhanh](#-hướng-dẫn-bắt-đầu-nhanh)
- [⚙️ Cấu hình & Thiết lập](#%EF%B8%8F-cấu-hình--thiết-lập)
- [📜 Nhật ký thay đổi (Changelog)](#-nhật-ký-thay-đổi-changelog)
- [📄 Giấy phép & Tác giả](#-giấy-phép--tác-giả)

---

## ✨ Tính năng cốt lõi

### 🛡️ 1. Động cơ bảo vệ (Intrusion Guard Engine)
- **Giám sát liên tục:** Tự động quét và phát hiện các thiết bị kết nối vào Mobile Hotspot của Windows mỗi 5 giây.
- **Chặn kép 2 tầng (Dual-Layer Blockade):**
  1. **Nhiễm độc ARP (Layer 2):** Ép gán địa chỉ IP của thiết bị xâm nhập vào MAC ảo (`00-00-00-00-00-01`) trong bảng ARP của Windows.
  2. **Tường lửa Windows (Layer 3):** Thêm quy tắc chặn Inbound tại card mạng Hotspot, từ chối toàn bộ gói tin từ IP lạ.
- **Tự động mở khóa (Auto-Recovery):** Khi thiết bị lạ được người dùng bổ sung vào danh sách trắng, hệ thống tự động gỡ chặn ngay trong chu kỳ tiếp theo.
- **Lọc trùng lặp thông minh:** Khắc phục triệt để hiện tượng Windows `Get-NetNeighbor` trả về nhiều dòng cho cùng 1 thiết bị vật lý (IPv4, IPv6, trạng thái stale).

### 📋 2. Quản lý Danh sách trắng (Whitelist)
- Thêm, sửa tên gọi (nickname) và xóa các thiết bị tin cậy bằng địa chỉ MAC.
- Tính năng **Sao lưu / Khôi phục (Import / Export JSON)** dữ liệu danh sách trắng nhanh chóng.
- Phím tắt Thêm vào danh sách trắng / Chặn ngay trên bảng Giám sát.

### 📶 3. Cấu hình Mobile Hotspot & Sửa lỗi ICS
- Tùy chỉnh SSID, Mật khẩu, Băng tần (2.4 GHz / 5 GHz) và số lượng thiết bị tối đa trực tiếp trong app.
- **🛠️ Sửa lỗi ICS bằng cách cưỡng chế dừng PID (Force PID-Kill):** Tự động phát hiện PID của `SharedAccess`, buộc dừng bằng `taskkill /F` và khởi động lại dịch vụ khi Windows bị treo ICS.
- **Tự động sửa lỗi IP/DHCP:** Quy trình 1-click làm mới toàn diện bộ đệm Winsock, xóa DNS và khởi động lại Hotspot.

### 🖥️ 4. Bảng điều khiển Console & Chẩn đoán
- Luồng ghi log trực tiếp theo mã màu, hỗ trợ lọc mức độ (INFO, WARN, BLOCK, OK), sao chép và xóa log.
- Tự động xoay vòng và cắt tỉa log: Giới hạn `wifi_guard.log` dưới 1MB (chỉ giữ lại 1.000 dòng gần nhất) và tự xóa log nhật ký hàng ngày sau 7 ngày.
- Chế độ chẩn đoán **`-debug`** (`debug.bat`) hiển thị huy hiệu thời gian biên dịch AOT (`DEBUG · v<version> (<build time>)`) với hiệu ứng Ping-Pong Marquee.

---

## 🚀 Hướng dẫn bắt đầu nhanh

### Cách 1: Sử dụng bản Portable phát hành (Khuyên dùng)
1. Tải file `JA_WiFi_Manager_v<version>_Windows_x64.zip` từ trang [Releases](https://github.com/jatechvn/JA_WiFi_Manager/releases).
2. Giải nén vào thư mục bất kỳ trên máy tính.
3. Chạy file `ja_wifi_manager.exe` bằng quyền Administrator (hoặc chấp nhận hộp thoại UAC khi app tự yêu cầu nâng quyền).

### Cách 2: Biên dịch từ mã nguồn
```cmd
git clone https://github.com/jatechvn/JA_WiFi_Manager.git
cd JA_WiFi_Manager
flutter pub get
flutter run -d windows
```
Hoặc đóng gói thành phẩm bằng script chuẩn:
```cmd
build.bat
```

---

## 📄 Giấy phép & Tác giả

Bản quyền thuộc về **John Alaa / JA Tech**. Mọi quyền được bảo lưu.

- **Tác giả:** John Alaa (`jatechvn`)
- **Website:** [https://jatechvn.github.io/](https://jatechvn.github.io/)
- **Repository:** [https://github.com/jatechvn/JA_WiFi_Manager](https://github.com/jatechvn/JA_WiFi_Manager)
