## Monitor-Light
Lightweight brightness control for Windows displays

Control the brightness of your built-in and external monitors directly from the Windows notification area.
Version 2.4.2 . by LoatriX

Download latest version . Report a bug . View releases

Overview

Monitor-Light is a lightweight Windows utility that controls the brightness of built-in laptop displays and
external monitors from the system tray.

Each detected display receives its own brightness slider. Changes are applied instantly, without opening
Windows Settings or using the physical buttons on the monitor.

Monitor-Light runs in the background and starts automatically with the current Windows user.

Features

. Built-in laptop display control through Windows WMI
. External display control through DDC/CI
. Individual brightness slider for every detected display
. Instant brightness adjustment
. Mouse-wheel brightness control
. Windows notification area integration
. Automatic startup with Windows
. English and French interface
. Persistent display settings
. Display detection and application reload controls
. Reset all displays to maximum brightness
. Automatic installation and uninstallation
. No administrator rights normally required
. Fixed light interface independent of the Windows theme

Screenshot

Monitor-Light interface

<img width="290" height="92" alt="image" src="https://github.com/user-attachments/assets/e9b010f6-6cc8-4efe-a5f5-9f9a332ff014" />


Requirements
. Windows 10 or Windows 11
. Windows PowerShell 5.1
. A compatible graphics driver for built-in display control
. DDC/CI-compatible external monitors
. DDC/CI enabled in the physical monitor settings
. HDMI, DisplayPort or USB-C connection supporting DDC/CI

Some docking stations, adapters and KVM switches may prevent DDC/CI commands from reaching the
display.

Installation

Recommended installation

1. Download Monitor-Light-v2.4.2.zip from the latest release.
2. Extract the complete ZIP archive.
3. Open the extracted folder.
4. Double-click install. cmd.
5. Wait for the installation confirmation.
6. Look for the Monitor-Light icon in the Windows notification area.

The application is installed in:

%LOCALAPPDATA%\Monitor-Light

C:\Users\user\AppData\Local\Monitor-Light
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
