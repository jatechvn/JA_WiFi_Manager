@echo off
setlocal enabledelayedexpansion
title Build Release Packager - JA WiFi Hotspot Guard

set WORKSPACE_DIR=%~dp0
cd /d "%WORKSPACE_DIR%"

:: 0. Kill running instances of the app
echo ============================================================
echo   [0/5] DANG TAT TIEN TRINH DANG CHAY (KILL PROCESS)...
echo ============================================================
taskkill /IM ja_wifi_manager.exe /F 2>nul
powershell -NoProfile -Command "Start-Sleep -Seconds 1" >nul 2>&1

:: 1. Clear previous distribution folder
echo ============================================================
echo   [1/5] DON DEP THU MUC DIST/...
echo ============================================================
if exist "dist" rmdir /s /q "dist"
mkdir "dist"

:: 2. Compile Windows Release App
echo ============================================================
echo   [2/5] BIEN DICH BAN RELEASE (FLUTTER BUILD WINDOWS)...
echo ============================================================
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Bien dich that bai! Ma loi: %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

set RELEASE_DIR=build\windows\x64\runner\Release

:: 3. Copy bin, assets, i18n, and docs to build output
echo ============================================================
echo   [3/5] DONG GOI TAI NGUYEN (ASSETS, I18N, DOCS)...
echo ============================================================
if exist "assets" xcopy /e /i /y /q "assets" "%RELEASE_DIR%\assets\"
if exist "i18n" xcopy /e /i /y /q "i18n" "%RELEASE_DIR%\i18n\"
if exist "ABOUT.txt" copy /y "ABOUT.txt" "%RELEASE_DIR%\" >nul
if exist "README.md" copy /y "README.md" "%RELEASE_DIR%\" >nul
if exist "CHANGELOG.md" copy /y "CHANGELOG.md" "%RELEASE_DIR%\" >nul
if exist "LICENSE" copy /y "LICENSE" "%RELEASE_DIR%\" >nul
if exist "install.bat" copy /y "install.bat" "%RELEASE_DIR%\" >nul
if exist "uninstall.bat" copy /y "uninstall.bat" "%RELEASE_DIR%\" >nul
if exist "uninstall.ps1" copy /y "uninstall.ps1" "%RELEASE_DIR%\" >nul

:: Copy/ensure debug.bat in release folder
if exist "debug.bat" (
    copy /y "debug.bat" "%RELEASE_DIR%\" >nul
) else (
    (
        echo @echo off
        echo cd /d %%~dp0
        echo for %%%%i in (*.exe^) do (
        echo     start "" "%%%%i" -debug
        echo     exit
        echo ^)
    ) > "%RELEASE_DIR%\debug.bat"
)

:: Create .Release shortcut in project root
echo Dang tao loi tat .Release.lnk tai thu muc goc...
powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%WORKSPACE_DIR%\.Release.lnk'); $s.TargetPath = '%WORKSPACE_DIR%\%RELEASE_DIR%'; $s.Save()"

:: Clean runtime logs before packaging
if exist "%RELEASE_DIR%\logs" rmdir /s /q "%RELEASE_DIR%\logs"
if exist "%RELEASE_DIR%\*.log" del /q "%RELEASE_DIR%\*.log"

:: 4. Copy to dist/
echo ============================================================
echo   [4/5] SAO CHEP VAO THU MUC DIST/...
echo ============================================================
xcopy /e /i /y /q "%RELEASE_DIR%\*.*" "dist\"

:: 5. Create x64 zip wrapped in parent folder
echo ============================================================
echo   [5/5] NEN GOI ZIP STANDALONE BO TRONG THU MUC ME...
echo ============================================================
for /f "tokens=2 delims=:" %%a in ('findstr /r "^version:" pubspec.yaml') do set RAW_VER=%%a
for /f "tokens=1 delims=+" %%v in ("%RAW_VER%") do set APP_VER=%%v
set APP_VER=%APP_VER: =%
if "%APP_VER%"=="" set APP_VER=1.1.7

set PKG_NAME=JA_WiFi_Manager_v%APP_VER%_Windows_x64

if exist "dist_pack" rmdir /s /q "dist_pack"
mkdir "dist_pack\%PKG_NAME%"
xcopy /e /i /y /q "dist\*.*" "dist_pack\%PKG_NAME%\"
powershell -NoProfile -Command "Compress-Archive -Path 'dist_pack\*' -DestinationPath 'dist\%PKG_NAME%.zip' -Force"
if exist "dist_pack" rmdir /s /q "dist_pack"

echo ============================================================
echo   [THANH CONG] DONG GOI RELEASE HOAN TAT!
echo   Tap tin zip: dist\%PKG_NAME%.zip
echo ============================================================
