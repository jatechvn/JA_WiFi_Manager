<div align="center">

  <img src="assets/app_icon.ico" width="96" height="96" alt="JA WiFi Hotspot Guard Logo" />

  # 🛡️ JA WiFi Hotspot Guard

  ### *Real-Time Intrusion Guard for Windows Mobile Hotspot*

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Platform](https://img.shields.io/badge/Platform-Windows_10_%7C_11-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://microsoft.com/windows)
  [![Release](https://img.shields.io/badge/Release-v1.1.6-00ADB5?style=for-the-badge&logo=github&logoColor=white)](https://github.com/jatechvn/JA_WiFi_Manager/releases)
  [![License](https://img.shields.io/badge/License-Proprietary-FFB100?style=for-the-badge)](#-license--author)

  <p align="center">
    <b>Monitor connected clients • Whitelist trusted devices • Auto-block intruders with ARP + Firewall</b>
  </p>

  ---

</div>

## 📑 Table of Contents

- [✨ Core Capabilities](#-core-capabilities)
- [🎨 UX & Personalization](#-ux--personalization)
- [📐 Directory & Technical Architecture](#-directory--technical-architecture)
- [🚀 Quick Start Guide](#-quick-start-guide)
- [⚙️ Configuration & Settings](#%EF%B8%8F-configuration--settings)
- [📜 Changelog](#-changelog)
- [📄 License & Author](#-license--author)

---

## ✨ Core Capabilities

### 🛡️ 1. Guard Engine (Intrusion Protection)
- **Continuous Monitoring:** Scans all clients connected to the Windows Mobile Hotspot every 5 seconds.
- **Dual-Layer Blockade:** Devices missing from the Whitelist are blocked at two levels simultaneously:
  1. **ARP Poisoning (Layer 2):** binds the intruder's IP to a fake MAC (`00-00-00-00-00-01`) in the Windows ARP cache.
  2. **Firewall Rule (Layer 3):** adds an inbound block rule on the hotspot network interface, rejecting all packets from the intruder's IP.
- **Auto-Recovery:** a device that reconnects and is whitelisted is automatically resolved and unblocked on the next check cycle.
- **Duplicate-Free Client List:** Windows' `Get-NetNeighbor` reports several rows per physical device (IPv4 + IPv6 link-local + stale entries) — the app deduplicates by MAC address with a priority score (IPv4 over IPv6, `Reachable` > `Stale` > `Permanent` > `Delay` > `Probe`) so Monitor never shows the same device twice.

### 📋 2. Whitelist Management
- Add, rename, and remove trusted devices with custom nicknames.
- One-click **Import / Export** of the whitelist as a portable JSON backup.
- Quick "Whitelist" / "Block" actions available directly from each row in the Monitor tab.

### 📶 3. Mobile Hotspot Configuration
- Configure SSID, password, band (2.4 GHz / 5 GHz) and max client count from a validated in-app form.
- Built-in **DHCP Auto-Fix** flow (restarts the Windows `SharedAccess` service) for hotspots stuck without IP assignment.
- "View Details" shortcut jumps straight to the Monitor tab for the configured network.

### 🖥️ 4. Console & Diagnostics
- Live, color-coded log stream with level filtering, auto-scroll toggle, copy-to-clipboard, and clear.
- **`-debug` launch mode** (`debug.bat`) switches every visible timestamp to full ISO precision and reveals a **build-time debug badge** — `DEBUG · v<version> (<build time>)` — next to the Guard Engine card, using a smooth bounce/ping-pong marquee for text longer than the sidebar width.

### 🔐 5. Admin & Safety
- Auto-elevates to Administrator on launch (ARP and firewall rule commands require it), forwarding all original CLI arguments (e.g. `-debug`, `--minimized`) through the elevation relaunch so no flag is silently lost.
- All preferences persist locally in `config.ini` — no cloud, no telemetry.

---

## 🎨 UX & Personalization

| Feature | Description |
| :--- | :--- |
| **Light / Dark Theme** | Manual toggle between Light and Dark; a fresh install defaults to whatever the Windows system theme currently is. |
| **Acrylic / Mica Blur** | Native transparent window backdrop — Acrylic on Windows 11, Aero/Mica fallback on Windows 10. |
| **System Tray Integration** | Minimize to tray, tray context menu, and optional "start minimized" launch. |
| **Multi-Language UI** | English 🇺🇸 / Tiếng Việt 🇻🇳 / 中文 🇨🇳, switchable live from the header. |

---

## 📐 Directory & Technical Architecture

```text
JA_WiFi_Manager/
├── dist/                                  # Portable distribution folder
│   └── JA_WiFi_Manager_v1.1.6_Windows_x64.zip   # Ready-to-ship release package
│
├── lib/
│   ├── main.dart                          # Entry point: CLI args, window init, admin elevation
│   └── modules/
│       ├── logic.dart                     # WifiGuardLogic — scanning, ARP/firewall, whitelist
│       ├── app_config.dart                # config.ini-backed persistent settings
│       ├── constants.dart                 # App name/version/status constants
│       ├── i18n.dart                      # EN / VI / ZH translations + LanguageNotifier
│       ├── utils.dart                     # Timestamp formatting, shared helpers
│       ├── logger_config.dart             # Rotating file logger (logs/<date>.log)
│       ├── native_bridge.dart             # NativeEngine contract
│       ├── native/
│       │   └── win_core.dart              # Windows ARP/firewall/admin-elevation commands
│       └── ui/
│           ├── main_window.dart           # Tab dispatcher & top-level state
│           ├── sidebar.dart                # Sidebar nav, Guard card, debug badge/marquee
│           ├── header_bar.dart             # Search, theme toggle, language cycle
│           ├── monitor_tab.dart            # Connected-client dashboard
│           ├── whitelist_tab.dart          # Whitelist CRUD + import/export
│           ├── hotspot_tab.dart            # Hotspot SSID/password/band config
│           ├── console_tab.dart            # Live log viewer
│           ├── settings_tab.dart           # Preferences + User Guide docs
│           ├── dialogs.dart                # Shared dialog widgets
│           └── styles.dart                 # AppColors, ThemeNotifier, shared widget styles
│
├── assets/                                # App icon and packaging scripts
├── ABOUT.txt                              # Project information card
├── README.md                              # This file
└── pubspec.yaml                           # Dependencies & Flutter manifest
```

---

## 🚀 Quick Start Guide

### Option A: Portable Run (No Installation Required)
1. Download `JA_WiFi_Manager_v1.1.6_Windows_x64.zip` from the latest release.
2. Extract the archive to any location.
3. Run `ja_wifi_manager.exe` — the app will prompt for Administrator rights on first launch (required for ARP/firewall control).
4. To run with the visible debug badge and full-precision log timestamps, double-click `debug.bat` instead.

### Option B: Building from Source (Developers)

#### Prerequisites
- **Windows 10 / 11** (64-bit)
- **Flutter SDK 3.x** & **Dart SDK 3.x**
- **Visual Studio 2022 / Build Tools** (Desktop development with C++)

```bash
# 1. Clone source repository
git clone https://github.com/jatechvn/JA_WiFi_Manager.git
cd JA_WiFi_Manager

# 2. Install Flutter packages
flutter pub get

# 3. Launch live developer mode
flutter run -d windows

# 4. Compile standalone Windows Release executable
flutter build windows --release
```

---

## ⚙️ Configuration & Settings

Preferences persist locally in `config.ini` next to the executable:

```ini
[app]
language=en
theme=dark
auto_start_guard=false
auto_start_hotspot=false
close_to_tray=true
start_minimized=false
check_interval_seconds=5
```

Whitelisted devices are stored separately in `whitelist.json`, exportable/importable from the Whitelist tab.

---

## 📜 Changelog

Refer to [CHANGELOG.md](CHANGELOG.md) for full version history details.

- **v1.1.6:** Fixed duplicate MAC rows in Monitor, added `-debug` launch mode with a build-time debug badge (bounce/ping-pong marquee for overflow text), fixed `-debug` being dropped during admin self-elevation, and reworked the theme toggle to default to the system theme.

---

## 📄 License & Author

Proprietary — All rights reserved.

- **Author:** John Alaa (`jatechvn`)
- **Website:** [https://jatechvn.github.io/](https://jatechvn.github.io/)
- **Repository:** [https://github.com/jatechvn/JA_WiFi_Manager](https://github.com/jatechvn/JA_WiFi_Manager)
