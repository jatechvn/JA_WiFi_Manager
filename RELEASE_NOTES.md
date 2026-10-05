TAG=v1.2.2
TITLE=JA WiFi Hotspot Guard v1.2.2 — Cổng khung hình Scheduler Power Gate, Coalescing UI Ẩn, Single Instance Mutex & Định danh Windows
BODY=
## JA WiFi Hotspot Guard v1.2.2 — Cổng khung hình Scheduler Power Gate, Coalescing UI Ẩn, Single Instance Mutex & Định danh Windows

- **Cổng khung hình Scheduler (Scheduler Power Gate):** Tích hợp `PowerWidgetsBinding` & `PowerFramePolicy`, kiểm soát `framesEnabled` dựa trên chính sách vòng đời và trạng thái kích hoạt, ngăn chặn khung hình vẽ dư thừa khi cửa sổ Inactive/Minimized hoặc ẩn khay hệ thống; tự động lên lịch vẽ bù một frame duy nhất ngay khi tái kích hoạt.
- **Gộp & Trì hoãn cập nhật UI ẩn (Hidden Presentation Coalescing):** Bổ sung `VisibleUiListener`, trì hoãn các lệnh cập nhật giao diện (`setState`) khi cửa sổ bị ẩn/thu nhỏ và gộp xả đúng 1 lần khi hiển thị lại, trong khi mọi tiến trình bảo mật ngầm tiếp tục chạy 100%.
- **Chống mở trùng lặp tiến trình (Windows Single Instance Mutex):** Sử dụng Mutex Win32 native trong `single_instance.h` và `main.cpp`, tự động đưa cửa sổ hiện có lên trước màn hình khi người dùng mở lại file thực thi.
- **Chuẩn hóa nhận diện Windows (App Identity & Manifest):** Cập nhật tên hiển thị thân thiện "JA WiFi Hotspot Guard" trong Windows Task Manager (`FileDescription` & `ProductName`), đồng bộ manifest tương thích Windows 10/11 và DPI awareness.
- **Tự động sinh Manifest OTA (`version.json`) & Cơ chế Dự phòng kép:** Script `build.bat` tự động sinh `dist/version.json` đồng bộ với `dist/SHA256SUMS.txt`; `OtaUpdateService` hỗ trợ fallback phân tích trực tiếp `SHA256SUMS.txt` khi thiếu manifest.
- **Bộ công cụ chẩn đoán hiệu năng & Đo đạc GPU:** Bổ sung các kịch bản PowerShell chuyên dụng (`scripts/measure_app_power.ps1`, `launch_profile_probe.ps1`, `capture_profile_probe.ps1`).
- **Khắc phục Race Condition trạng thái cửa sổ:** `AppPowerManager` quản lý revision tokens cho các truy vấn bất đồng bộ `isFocused`/`isVisible`, loại bỏ tình trạng ghi đè trạng thái cũ và tuần tự hóa hàng đợi thao tác khay hệ thống.

### Cài đặt
Giải nén toàn bộ `JA_WiFi_Manager_v1.2.2_Windows_x64.zip` và chạy `ja_wifi_manager.exe`. Xem `USERGUIDE.md` trong gói để biết thêm chi tiết.
