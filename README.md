# 🚀 TeamSpeak 3 Server Auto Installer

A powerful, cross-platform installer for the **TeamSpeak 3 Server**, supporting **Linux**, **macOS**, and **Windows** with automation, upgrade detection, firewall configuration, and autostart options.

---

## 📦 Features

✅ Easy installation on **Linux**, **macOS**, and **Windows**  
🔄 Detects and upgrades existing installations  
🧱 Sets up **systemd** or **LaunchAgent** for auto-start  
🛡️ Automatically configures firewall rules  
🔐 Saves **ServerAdmin token** and **Query login** securely (linux and Mac only)
🌐 Fetches and displays your external IP  (linux and Mac only)
🧪 Supports `x86_64` / `amd64` architectures as teamspeak doesnt support arm arch.

---

## 🧰 Files

| File | Description |
|------|-------------|
| `install.sh` | Cross-platform shell script for Linux/macOS |
| `install_ts3-server_windows.ps1` | PowerShell script for Windows installation |

---

## 🖥️ Installation Guide

### 📗 Linux / macOS

```bash
curl -O https://github.com/ChocoJaYY/ts3server-autoinstaller/install.sh
chmod +x install.sh
./install.sh
```

- 💡 Supports `systemd` on Linux
- 💡 Offers LaunchAgent support for macOS autostart

### 📘 Windows (PowerShell)

1. Download `install_ts3-server_windows.ps1`
2. Run it as **Administrator**:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install_ts3-server_windows.ps1
```
> "Set-ExecutionPolicy Bypass -Scope Process -Force" will bypass execution policy of powershell. so we can run these unsigned scripts.
> Ensure [7-Zip](https://www.7-zip.org/) is installed for better extraction performance. Falls back to native tools if not found. (I will add autoinstall feature sooner)

---

## ⚙️ Ports Opened

| Service | Port | Protocol |
|---------|------|----------|
| Voice   | 9987 | UDP      |
| Query   | 10011 | TCP     |
| File Transfer | 30033 | TCP |

---

## 🔐 Post Installation Output

- 🗝️ **ServerAdmin Privilege Key**
- 👤 **Query Login** (username & password)
- 🌐 **External IP Address**
- 📁 All credentials are saved inside the `ts3server` directory.

---

## 📂 Default Installation Paths

| OS      | Path                  |
|---------|-----------------------|
| Linux   | `/opt/ts3server`      |
| macOS   | `~/ts3server`         |
| Windows | `C:\TS3Server` (Default) |

---

## 🧪 Tested On

- Ubuntu 24.04 LTS
- macOS Sequoia (Intel)
- Windows 10 / 11 / Server 2022

---

## 🙌 Contributing

Feel free to fork and submit pull requests or issues. All suggestions are welcome!

---

## 📜 License

This project is licensed under the **MIT License**.

---


## 🧠 Author

Made with ❤️ by [ChocoJaYY](https://github.com/ChocoJaYY)
