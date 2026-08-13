---
name: dart-build-pro
description: Quy trình tự động biên dịch, đóng gói và phát hành ứng dụng Dart / Flutter Windows Desktop chuyên nghiệp. Kích hoạt khi người dùng yêu cầu build app, đóng gói release hay tạo file zip phát hành cho dự án Dart/Flutter.
---

# Dart & Flutter Windows Build & Packaging Guide (`dart-build-pro`)

Hướng dẫn chuẩn hóa quy trình biên dịch, tích hợp công cụ nhúng (`bin/`, `assets/`, `i18n/`, tài liệu), tắt ứng dụng đang chạy, và nén gói phát hành chuẩn `x64` bao bọc trong **thư mục mẹ (parent folder)** cho ứng dụng Flutter Desktop trên Windows.

## Quy trình 5 bước Build & Packaging chuẩn:

### 1. Tắt ứng dụng đang chạy (Kill Process)
Trước khi biên dịch hoặc dọn dẹp file, luôn tắt tiến trình ứng dụng đang chạy để tránh lỗi khóa file (`ERROR_SHARING_VIOLATION`):
```cmd
taskkill /IM <app_name>.exe /F 2>nul
```

### 2. Dọn dẹp Cache biên dịch (Clean Cache)
Nếu chuyển thư mục hoặc có thay đổi mã nguồn/C++, xóa các thư mục tạm để tránh xung đột CMakeCache:
```cmd
if exist build rmdir /s /q build
if exist .dart_tool rmdir /s /q .dart_tool
if exist windows\flutter\ephemeral rmdir /s /q windows\flutter\ephemeral
```

### 3. Biên dịch bản Release (Flutter Release Build)
Thực thi lệnh build ứng dụng Windows ở chế độ Release:
```cmd
flutter build windows --release
```

### 4. Đóng gói đầy đủ phụ kiện (`bin/`, `assets/`, `i18n/`, `docs`)
Copy đầy đủ các bộ công cụ nhúng và tài nguyên vào thư mục đầu ra `build\windows\x64\runner\Release\` và thư mục `dist/`:
- `bin/` -> Công cụ nhúng (`gh.exe`, `git/`)
- `assets/` -> Hình ảnh, biểu tượng
- `i18n/` -> Tệp ngôn ngữ đa quốc gia
- `debug.bat`, `ABOUT.txt`, `README.md`, `CHANGELOG.md`, `LICENSE` -> Tài liệu & File debug

Lệnh đóng gói (`build_release.bat`):
```cmd
@echo off
setlocal enabledelayedexpansion
title Build Release Packager

set WORKSPACE_DIR=%~dp0
cd /d "%WORKSPACE_DIR%"

taskkill /IM <app_name>.exe /F 2>nul
if exist "dist" rmdir /s /q "dist"
mkdir "dist"

call flutter build windows --release
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

set REL=build\windows\x64\runner\Release
if exist bin xcopy /e /i /y /q bin %REL%\bin\
if exist assets xcopy /e /i /y /q assets %REL%\assets\
if exist i18n xcopy /e /i /y /q i18n %REL%\i18n\
if exist debug.bat copy /y debug.bat %REL%\
if exist ABOUT.txt copy /y ABOUT.txt %REL%\
if exist README.md copy /y README.md %REL%\
if exist CHANGELOG.md copy /y CHANGELOG.md %REL%\
if exist LICENSE copy /y LICENSE %REL%\

xcopy /e /i /y /q %REL%\*.* dist\

if exist "dist_pack" rmdir /s /q "dist_pack"
mkdir "dist_pack\<App_Name>_v1.0.0_Windows_x64"
xcopy /e /i /y /q "dist\*.*" "dist_pack\<App_Name>_v1.0.0_Windows_x64\"
powershell -Command "Compress-Archive -Path 'dist_pack\*' -DestinationPath 'dist\<App_Name>_v1.0.0_Windows_x64.zip' -Force"
if exist "dist_pack" rmdir /s /q "dist_pack"
```

### 5. Tạo gói Nén ZIP Phát hành bọc trong Thư mục Mẹ (Parent Folder Packaging)
**Quy tắc bắt buộc:** Để tránh bung file tự do ra ngoài khi người dùng giải nén, tất cả file phải được bọc trong một **thư mục mẹ (parent folder)** có tên định dạng `<App_Name>_v<Version>_Windows_x64`:

```powershell
powershell -Command "if (Test-Path 'dist_pack') { Remove-Item 'dist_pack' -Recurse -Force }; New-Item -ItemType Directory -Path 'dist_pack\<App_Name>_v1.0.0_Windows_x64' -Force; Copy-Item -Path 'dist\*' -Destination 'dist_pack\<App_Name>_v1.0.0_Windows_x64' -Recurse -Force; Remove-Item 'dist_pack\<App_Name>_v1.0.0_Windows_x64\*.zip' -ErrorAction SilentlyContinue; Remove-Item 'dist\<App_Name>_v1.0.0_Windows_x64.zip' -ErrorAction SilentlyContinue; Compress-Archive -Path 'dist_pack\*' -DestinationPath 'dist\<App_Name>_v1.0.0_Windows_x64.zip' -Force; Remove-Item 'dist_pack' -Recurse -Force"
```

---

## Từ khóa gán Skill:
Mỗi khi người dùng gõ hoặc yêu cầu các lệnh:
- `/build` hoặc `build app` hoặc `gọi skill build` hoặc `build release`
- AI sẽ tự động kích hoạt Skill `dart-build-pro` và thực hiện trọn vẹn quy trình 5 bước trên.

## Hướng dẫn cấu hình Debug & Logger chuẩn
Để hỗ trợ việc gỡ lỗi ứng dụng sau khi đã build release, file `debug.bat` cần được thiết kế để chạy trực tiếp file `.exe` đã biên dịch chứ không phải dùng lệnh `flutter run`.

### 1. Nội dung chuẩn cho `debug.bat`:
```cmd
@echo off
cd /d %~dp0
for %%i in (*.exe) do (
    start "" "%%i" -debug
    exit
)
```

### 2. Cấu hình timestamp trong Logger (Debug mode)
Để log lưu trữ đầy đủ thông tin thời gian, cần sử dụng định dạng ISO hoàn chỉnh `DateTime.now().toIso8601String()` cho chế độ debug.
Ví dụ cấu hình trong Dart:
```dart
  static void log(String message, {String level = 'INFO', Object? error, StackTrace? stackTrace}) {
    // Sử dụng full ISO cho debug mode để có chi tiết ngày giờ và mili-giây
    final timestamp = isDebugMode ? DateTime.now().toIso8601String() : DateTime.now().toIso8601String().substring(11, 19);
    var formatted = '[$timestamp] [$level] $message';
    // ...
  }
```

**Lưu ý:** đảm bảo timestamp debug này áp dụng cho ĐÚNG hàm format đang thực sự hiển thị trên UI (ví dụ tab Console/Logs) — không chỉ cho một logger nội bộ ghi ra file riêng mà người dùng không nhìn thấy. Kiểm tra bằng cách grep xem UI đang gọi hàm format nào trước khi sửa.

### 3. Debug Badge hiển thị trên giao diện chính (bắt buộc)
Ngoài log ra file/console, app PHẢI có một badge nhỏ, luôn hiển thị trên giao diện chính (đặt gần khu vực trạng thái/engine chính của app, ví dụ cạnh card trạng thái hoạt động) khi chạy ở chế độ debug, theo đúng format:

```
DEBUG · v<version> (<build time>)
```

Ví dụ: `DEBUG · v2.4.0 (2026-08-11 14:27:38)`

- `<version>` lấy từ hằng số version của app (constants.dart hoặc tương đương).
- `<build time>` là **thời điểm build ra binary**, KHÔNG PHẢI thời gian hiện tại (không dùng đồng hồ sống/ticking). Lấy từ mtime của artifact biên dịch AOT (`data/app.so` với Windows Release build), fallback về mtime của chính file `.exe` nếu không có `app.so` (ví dụ bản debug/JIT chạy qua `flutter run`).
- Format thời gian: `yyyy-MM-dd HH:mm:ss` (không dùng ISO có chữ `T`/mili-giây ở badge này — ISO đầy đủ chỉ dùng cho log, xem mục 2).
- Chỉ hiển thị khi app được khởi chạy với cờ `-debug` (ẩn hoàn toàn ở chế độ bình thường).

### 4. Lưu ý khi app tự nâng quyền Admin (self-elevation)
Nếu app cần chạy quyền Administrator và tự relaunch bằng `Start-Process ... -Verb RunAs` (hoặc cơ chế tương đương), **PHẢI forward lại toàn bộ command-line args gốc** (bao gồm `-debug`) sang tiến trình elevated mới, ví dụ dùng `-ArgumentList`:
```powershell
Start-Process "<exePath>" -ArgumentList "-debug" -Verb RunAs
```
Nếu quên bước này, tiến trình elevated (tiến trình người dùng thực sự tương tác) sẽ luôn khởi động với danh sách args rỗng — cờ `-debug` bị mất silently dù người dùng đã chạy đúng `debug.bat`, rất khó phát hiện vì không có lỗi nào được ném ra.
