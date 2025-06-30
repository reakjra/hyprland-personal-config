# 🛠️ Hyprland Config - My Personal Linux Setup

Welcome to my personal configuration and survival guide for setting up Hyprland and gaming-related tweaks on Arch-based systems (EndeavourOS).  
This README includes tips, scripts, and setup instructions that I've collected to help me rebuild my setup quickly whenever needed.

---

## 📚 Table of Contents

- [📦 Mounting NTFS Drives](#mounting-ntfs-drives)
- [🖥️ GRUB Resolution Fix](#grub-resolution-fix)
- [❄️ Undervolting NVIDIA](https://github.com/reakjra/hyprland-config/blob/main/gpu/readme.md)
- [🌈 Extra: Gamma, Contrast and Saturation](#extra-gamma-contrast-and-saturation)

---

##  Mounting NTFS Drives

First, install the NTFS driver:

```bash
sudo pacman -S ntfs-3g
```

Get the list of drives and their UUIDs:

```bash
lsblk -o NAME,SIZE,UUID
```

Create a mount point (directory):

```bash
mkdir -p ~/MountedDrive
```

Mount manually to test:

```bash
sudo mount ntfs-3g /dev/<drive-name> ~/MountedDrive -o uid=$(id -u),gid=$(id -g)
```

If it works, edit `fstab` to mount the drive automatically at boot:

```bash
sudo nano /etc/fstab
```

Add this line (replace with your actual UUID and username):

```bash
UUID=<drive-uuid> /home/<username>/MountedDrive ntfs-3g defaults,uid=1000,gid=1000,rw,user,exec,umask=000 0 0
```

Test it:

```bash
sudo umount ~/MountedDrive
sudo mount -a
ls -l ~/MountedDrive
```
---

##  GRUB Resolution Fix

By default, GRUB might boot in a low-res, ugly-looking mode. Here's how to set it to 1920x1080.

1. Edit the GRUB config:
```bash
sudo nano /etc/default/grub
```

2. Add or modify these lines:

```bash
GRUB_GFXMODE=1920x1080
GRUB_GFXPAYLOAD_LINUX=keep
```

3. Save the file and update GRUB:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

 Tip: If using a distro with different paths (like Fedora or Btrfs), double-check your `/boot` structure.

4. Reboot and enjoy crispy-clear boot text!

---

## Extra: Gamma, Contrast and Saturation

Most in-game settings let you tweak gamma/contrast, but **saturation** is trickier on Linux.

### Options:

- Use monitor hardware controls (annoying but reliable)
- Try tools like:
  - `gamescope` (if supported)
  - `xrandr` (less useful on Wayland)
  - Color profiles (ICC) or HDR LUTs if you want to go deeper

---
