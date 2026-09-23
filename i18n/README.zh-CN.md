<div align="center">

  <img src="../assets/app_icon.ico" width="96" height="96" alt="JA WiFi Hotspot Guard Logo" />

  # 🛡️ JA WiFi Hotspot Guard

  ### *Windows 移动热点实时入侵防御与白名单管理系统*

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Platform](https://img.shields.io/badge/Platform-Windows_10_%7C_11-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://microsoft.com/windows)
  [![Release](https://img.shields.io/badge/Release-v1.1.8-00ADB5?style=for-the-badge&logo=github&logoColor=white)](https://github.com/jatechvn/JA_WiFi_Manager/releases)
  [![License](https://img.shields.io/badge/License-Proprietary-FFB100?style=for-the-badge)](#-许可证与作者)

  <p align="center">
    <a href="../README.md">🇺🇸 English</a> • <a href="README.vi.md">🇻🇳 Tiếng Việt</a> • <b>🇨🇳 中文</b>
  </p>

  <p align="center">
    <b>实时监控连接设备 • 白名单安全过滤 • ARP欺骗与Windows防火墙双层自动拦截</b>
  </p>

  ---

</div>

## 📑 目录

- [✨ 核心功能](#-核心功能)
- [🎨 界面与个性化](#-界面与个性化)
- [🚀 快速开始](#-快速开始)
- [⚙️ 配置说明](#%EF%B8%8F-配置说明)
- [📜 更新日志](#-更新日志)
- [📄 许可证与作者](#-许可证与作者)

---

## ✨ 核心功能

### 🛡️ 1. 防御引擎 (Intrusion Guard Engine)
- **持续监控：** 每5秒自动扫描连接到 Windows 移动热点的所有设备。
- **双层拦截防御：**
  1. **ARP欺骗拦截 (Layer 2)：** 将未授权设备的 IP 绑定至虚假 MAC 地址（`00-00-00-00-00-01`）。
  2. **防火墙规则拦截 (Layer 3)：** 在热点网卡上创建入站规则，直接拒绝所有来自该 IP 的网络数据包。
- **自动恢复解除拦截：** 当设备被添加到白名单后，系统会在下一个扫描周期自动解除封锁。

### 📋 2. 白名单管理 (Whitelist)
- 轻松添加、修改设备昵称以及删除信任的 MAC 地址。
- 支持 **JSON 数据导入与导出** 备份。
- 在监控列表中可直接执行快速加白与拉黑操作。

### 📶 3. 移动热点配置与 ICS 故障修复
- 直接在软件中配置 SSID、密码、频段（2.4GHz / 5GHz）和最大连接设备数。
- **强制终止 PID 修复 ICS 服务：** 当 Windows Internet 连接共享 (`SharedAccess`) 卡死时，通过精确定位 PID 并强制终止，重新平滑拉起服务。
- 一键式 IP/DHCP 与 Winsock 重置排障流程。

### 🖥️ 4. 控制台日志与自动轮转
- 多级别色彩日志输出，支持搜索、过滤与一键清除。
- 自动体积控制：当 `wifi_guard.log` 超过 1MB 时自动截断保留最新 1,000 行；超过 7 天的历史日志自动清理。
- 支持 **`-debug`** 命令行参数与 AOT 编译时间戳徽章。

---

## 🚀 快速开始

### 方式一：便携版使用（推荐）
1. 前往 [Releases](https://github.com/jatechvn/JA_WiFi_Manager/releases) 下载 `JA_WiFi_Manager_v<version>_Windows_x64.zip`。
2. 解压至任意文件夹。
3. 以管理员身份运行 `ja_wifi_manager.exe`。

### 方式二：从源码编译
```cmd
git clone https://github.com/jatechvn/JA_WiFi_Manager.git
cd JA_WiFi_Manager
flutter pub get
flutter run -d windows
```
或者使用一键打包脚本：
```cmd
build.bat
```

---

## 📄 许可证与作者

版权所有 © **John Alaa / JA Tech**。保留所有权利。

- **作者：** John Alaa (`jatechvn`)
- **官网：** [https://jatechvn.github.io/](https://jatechvn.github.io/)
- **仓库地址：** [https://github.com/jatechvn/JA_WiFi_Manager](https://github.com/jatechvn/JA_WiFi_Manager)
