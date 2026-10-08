# IPBan Control Center

[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%20Server-0078D6.svg?logo=windows)](https://microsoft.com)
[![PowerShell: 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Languages: EN | UA](https://img.shields.io/badge/Language-English%20%7C%20Ukrainian-orange.svg)](#multi-language-support)

A full-featured, modern Windows graphical user interface (GUI) and management suite for [DigitalRuby IPBan](https://github.com/DigitalRuby/IPBan) security service.

Designed for system administrators, DevOps, and power users running Windows 10, Windows 11, or Windows Server (2012 R2, 2016, 2019, 2022, 2025).

> 🇺🇦 **Українська версія документації**: доступна у файлі [README_IPBan_GUI.md](README_IPBan_GUI.md).

---

## Key Features

- **🛡️ Full IPBan Service Control**: Start, stop, restart, monitor service status in real-time.
- **🔔 System Tray Integration**:
  - Color-coded shield icons: **Green** (Running & Protected), **Red** (Stopped/Missing), **Orange** (Alert with exclamation badge).
  - Native Windows balloon notifications on new attacker IP ban events.
  - Right-click tray menu for quick actions and IP ban counters.
  - Minimizes to tray on close [X] without interrupting protection.
- **🚫 Banned IPs Management (Windows Firewall)**:
  - Live inspection of active firewall rules (`IPBan_*`).
  - Search / filter IPs on the fly.
  - Unban selected IPs immediately via `unban.txt` and firewall synchronization.
  - Manually ban suspicious IPs or subnets.
  - Export banned list to `.txt` or `.csv`.
  - Context menu with one-click IP lookup (Whois / geolocation via ipinfo.io) and Whitelist addition.
- **⚙️ Configuration Editor (`ipban.config`)**:
  - Visual controls for failed attempt thresholds, ban durations (presets or custom), cycle intervals, and behavior switches.
  - Automatic backup creation (`ipban.config.bak`) prior to saving with one-click restore.
- **📋 Whitelist & Blacklist Manager**:
  - Manage trusted subnets and malicious botnet IPs.
  - **Self-lockout protection**: one-click buttons to detect and whitelist local network adapters (`+ Add Local IP`) and public IP (`+ Add Public WAN IP`).
- **📊 Security Audit & Attack Event Log (Event ID 4625)**:
  - Live parsing of failed Windows logon events (RDP, Network, SMB, Interactive).
  - Details: Timestamp, Username, Source IP, Logon Type, Workstation.
  - Quick action to ban attacking IP directly from the event row.
  - Real-time IPBan `logfile.txt` viewer with auto-refresh.
- **🚀 Built-in Setup & Deployment Wizard**:
  - Check Windows audit policies and enable them with one click (`AuditPol`).
  - Install IPBan service directly from official GitHub releases or from local ZIP package on any drive.
  - Clean service uninstall option.
- **🌐 Dual Language Support (EN / UA)**:
  - Seamless switching between English and Ukrainian with persistent registry storage and automatic OS locale detection.
- **📦 Single-File Standalone Binaries**:
  - Fully self-contained `.exe` executables with embedded scripts and icons: run without needing external file dependencies.

---

## Installation & Usage

### Option 1: Standalone Installer (Recommended)
1. Launch **`Setup_IPBanGUI.exe`** (or `Setup_IPBan_Control_Center.bat`).
2. The installation wizard will guide you through:
   - Selecting the installation directory (default: `C:\Program Files\IPBan Manager`).
   - Desktop and Start Menu shortcut creation.
   - Windows Startup configuration (minimized to system tray upon logon).
   - Automated Windows Security Audit policy activation (`AuditPol`).
   - Verification of the IPBan service.
3. Registered in Windows **Add/Remove Programs** with a clean uninstaller (`Uninstall.bat` / `Uninstall.ps1`) that gracefully terminates tray processes and services.

### Option 2: Portable / Standalone Execution
- Run **`IPBanControlCenter.exe`** (or `Run_IPBan_GUI.bat`).
- Automatically requests administrative elevation (UAC) if needed.
- If run standalone without surrounding files, unpacks and runs its embedded payload automatically.

---

## Multi-Language Support

The application automatically selects its language based on your Windows OS locale:
- **Ukrainian (UA)** for Ukrainian OS environments.
- **English (EN)** for all other locales.

You can toggle the language at any time:
- In **Installer**: use the language selector in the left sidebar.
- In **Control Center**: click the **`🌐 EN`** / **`🌐 UA`** button in the top header.
- Preferences are saved in `HKCU:\SOFTWARE\IPBanControlCenter\Language`.

---

## Building from Source

To compile the standalone single-file `.exe` binaries with embedded assets:

```powershell
powershell -ExecutionPolicy Bypass -File .\Build_Binaries.ps1
```

This compiles:
1. `app.ico` – Generated multi-layer shield icon.
2. `IPBanControlCenter.exe` – Standalone C# launcher embedding `IPBanGUI.ps1`.
3. `Setup_IPBanGUI.exe` – Standalone installer embedding the wizard and all dependencies.

---

## System Requirements

- **Operating System**: Windows 10, Windows 11, Windows Server 2012 R2 / 2016 / 2019 / 2022 / 2025 (x64)
- **PowerShell**: Version 4.0 or newer (built into Windows Server 2012 R2 and later)
- **Privileges**: Local Administrator (required for managing Windows services and firewall rules)

---

## License

This project is licensed under the [MIT License](LICENSE).
IPBan is created and maintained by Jeff Johnson / Digital Ruby.
