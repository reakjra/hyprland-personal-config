# NVIDIA Undervolting & Fan Control Guide

> step-by-step guide to undervolt your NVIDIA GPU on Lusing power limits and fan control scripts

---

## Table of Contents

- [1. Update the system](#1-update-the-system)
- [2. Download and set scripts](#2-download-and-set-scripts)
- [3. Configure sudoers](#3-configure-sudoers)
- [4. Install Nvidia utils and xhost](#4-install-nvidia-utils-and-xhost)
- [5. Enable CoolBits and add scripts to Hyprland config](#5-enable-coolbits-and-add-scripts-to-hyprland-config)
- [Troubleshooting](#troubleshooting)

---

## 1. Update the system

Keep your system up-to-date:

```bash
sudo pacman -Syu
```

---

## 2. Download and set scripts

Download your scripts (`nvidia_fan_control.sh` and `gpu-limit.sh`) and place them in your home directory:

```bash
~/ 
```

Make them executable:

```bash
sudo chmod +x ~/nvidia_fan_control.sh
sudo chmod +x ~/gpu-limit.sh
```

---

## 3. Configure sudoers

Allow the scripts to run commands without password prompts:

```bash
sudo nano /etc/sudoers.d/gpucontrol
```

Add the following lines (replace `<username>` with your actual username):

```text
<username> ALL=(ALL) NOPASSWD: /usr/bin/nvidia-settings
<username> ALL=(ALL) NOPASSWD: /usr/bin/nvidia-smi
<username> ALL=(ALL) NOPASSWD: /usr/bin/env
```

Save and exit.

---

## 4. Install Nvidia utils and xhost

Install necessary packages:

```bash
sudo pacman -S nvidia nvidia-utils nvidia-settings xorg-xhost
```

Run xhost to allow root to access X:

```bash
xhost +si:localuser:root
sudo nvidia-settings
```

Use `nvidia-settings` GUI to enable and customize your fan curve.

---

## 5. Enable CoolBits and add scripts to Hyprland config

### Enable CoolBits in the Nvidia config

Edit or create the Nvidia X11 config file:

```bash
sudo nano /etc/X11/xorg.conf.d/20-nvidia.conf
```

Add the following section:

```sh
Section "Device"
    Identifier "Nvidia Card"
    Driver "nvidia"
    Option "CoolBits" "4"  # "4" enables fan control; "8", "12", or "28" enable more features.
EndSection
```

Save and exit.

### Add the scripts to your `hyprland.conf`

Edit your Hyprland config:

```bash
sudo nano ~/.config/hypr/hyprland.conf
```

Add these lines (replace `<username>`):

```sh
exec = ~/gpu-limit.sh
exec-once = bash -c "sleep 1 && xhost +si:localuser:root && sleep 2 && /home/<username>/nvidia_fan_control.sh &"
```

This will apply power limits and start fan control on startup.

> NOTE: Power limiting the GPU might affect your performances, however, with my current 3060 Ti from `200w` to `130w` I've never encountered performance issues and barely noticeable fps loss.

---

## Troubleshooting

If you encounter login or display issues (especially with SDDM and NVIDIA), try adding this to `hyprland.conf`:

```sh
env = WLR_NO_HARDWARE_CURSOR,1
env = __GL_VRR_RATE,0
env = LIBVA_DRIVER_NAME,nvidia

exec-once = dbus-update-activation-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
```

---

*Feel free to suggest improvements or open issues if you run into trouble.*
