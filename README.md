# IFOKNR - Thermal Manager

[![Platform](https://img.shields.io/badge/Platform-Android%2014%2B%20%7C%20One%20UI-blue.svg)](https://www.samsung.com)
[![Device](https://img.shields.io/badge/Device-Galaxy%20Tab%20S10%20Ultra-00f0ff.svg)](https://www.samsung.com)
[![SoC](https://img.shields.io/badge/SoC-Dimensity%209300%2B-ff0055.svg)](https://www.mediatek.com)
[![Root](https://img.shields.io/badge/Root-KernelSU%20%7C%20APatch%20%7C%20Magisk-green.svg)](#installation)
[![License](https://img.shields.io/badge/License-GPL--3.0-orange.svg)](LICENSE)

A specialized performance management module custom-tailored for the **Samsung Galaxy Tab S10 Ultra (MediaTek Dimensity 9300+)**. 

This project is a dedicated fork of [Ahmed Al-Nassif's Thermal Manager](https://github.com/ahmed-alnassif), re-engineered specifically to accommodate Samsung's One UI environment, MediaTek's **All-Big-Core** architecture, and high-refresh-rate gaming—while ensuring **zero conflicts** with secondary thermal-locking modules.

---

## ⚡ What Makes This Fork Different?

* **Zero-Conflict Hardware Handling:** Unlike standard thermal modules, this build explicitly excludes general `thermal_zone` tampering. It operates cleanly alongside secondary thermal modules without competing for kernel thermal locks.
* **Dimensity 9300+ Core Scheduling:** Tuned governor thresholds and frequency limits across both Cortex-X4 clusters (`cpu[0-3]` and `cpu[4-7]`).
* **MediaTek GED GPU Boost:** Directly interfaces with `/sys/module/ged/parameters` to force hardware acceleration during graphics-intensive loads.
* **Samsung GOS Bypass:** Automatically halts Samsung's Game Optimizing Service (`com.samsung.android.game.gos`) and Game Tools in high-performance profiles to prevent aggressive thermal throttling.
* **Cyberpunk AMOLED WebUI:** Rebuilt interface featuring a pure black AMOLED foundation (`#030508`), dual-tone Neon HUD accents (Cyan & Pink), frosted-glass containers, and direct hardware state inspection.

---

## 🎯 Profile Breakdown

| Profile | CPU Cluster Policy | GPU Acceleration (GED) | Samsung GOS State | Recommended Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **⚖️ Balanced** | Default dynamic frequencies (`schedutil`) | Stock power curve | Enabled | Daily media, productivity, multi-window tasks |
| **🔋 Battery** | Max frequency capped at **1.4 GHz** (`powersave`) | Low-power mode | Enabled | Reading, long standby, extended battery preservation |
| **⚡ Performance** | Uncapped dynamic boost (`schedutil`) | Level 1 Acceleration | Disabled | Fast app compilation, heavy multitasking |
| **🎮 Gaming** | **1.8 GHz minimum floor** on Cortex-X4 cores | Max GPU Boost (`gx_game_mode=1`) | Disabled | AAA gaming, emulator workloads, zero micro-stutter |

---

## 🌟 Key Features

* **Real-time WebUI:** Seamlessly switch performance modes from inside KernelSU, ReSukiSU, or APatch WebUI without rebooting.
* **Auto Battery Saver:** Background screen-off awareness via power hal checks; instantly transitions to energy-saving states when the screen locks, and restores the active profile upon unlocking.
* **Persistent Settings:** Automatically restores the selected profile upon system reboot.
* **Clean Process Tracking:** Managed daemon utilizing lightweight PID check cycles without battery drain.

---

## 🛠️ Installation

1. Download the latest `IFOKNR-Thermal-Manager-*.zip` from the [Releases](https://github.com/ifoknr/Thermal-Manager-Samsung-Galaxy-Tab-S10-Ultra/releases) page.
2. Open your root manager (**KernelSU**, **ReSukiSU**, **APatch**, or **Magisk**).
3. Navigate to **Modules** → **Install from storage** and select the ZIP file.
4. Reboot your tablet once the installation completes.
5. Launch the interface from **KernelSU/ReSukiSU** → **Modules** → **IFOKNR - Thermal Manager WebUI**.

---

## 🤝 Credits & Acknowledgements

* **Original Developer:** [Ahmed Al-Nassif](https://github.com/ahmed-alnassif) for the initial foundation and WebUI concepts.
* **Modification & Optimization:** Maintained by **[ifoknr](https://github.com/ifoknr)** specifically for Samsung Galaxy Tab S10 Ultra devices.

---

## 📄 License
This project is licensed under the [GNU General Public License v3.0](LICENSE).