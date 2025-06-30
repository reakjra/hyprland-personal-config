# 🛠️ Hyprland Config - My Personal Linux Setup

Welcome to my personal configuration and survival guide for setting up Hyprland and gaming-related tweaks on Arch-based systems (EndeavourOS).  
This README includes tips, scripts, and setup instructions that I've collected to help me rebuild my setup quickly whenever needed.

---

## 📚 Table of Contents

- [📦 Mounting NTFS Drives](#mounting-ntfs-drives)
- [🖥️ GRUB Resolution Fix](#grub-resolution-fix)
- [❄️ Undervolting NVIDIA](https://github.com/reakjra/hyprland-config/blob/main/gpu/readme.md)
- [Date & Time Fix for Dual Boot](#date--time-fix-for-dual-boot)
- [Discord Update & White Screen Fix](#discord-update--white-screen-fix)
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

## Date & Time Fix for Dual Boot

If you dual boot with Windows, Windows may show the wrong time due it using local RTC (real-time clock) which leads Linux having the correct time but Windows doesn´t.

Fix it by running:

```bash
sudo timedatectl set-local-rtc 1 --adjust-system-clock
```

This tells Linux to treat the hardware clock as local time and adjust the system clock accordingly. In windows remember to go to settings and disable and enable the automatic sync option.

---

## Discord Update & White Screen Fix

### Problem:

Discord sometimes asks for an update to version `0.0.0.100` and then shows a completely white window. Changing distros or reinstalling doesn't fix it.

### Fix steps:

1. Kill any running Discord processes:

```bash
pkill discord
pkill Discord
```

2. Uninstall Discord completely:

- If installed via pacman:

```bash
sudo pacman -Rns discord
```

- If installed via AUR (e.g. yay):

```bash
yay -Rns discord
```

3. Remove all Discord-related user config and cache files:

```bash
rm -rf ~/.cache/discord ~/.cache/Discord
rm -rf ~/.config/discord ~/.config/Discord
rm -rf ~/.local/share/discord ~/.local/share/Discord
rm -rf ~/.local/state/discord ~/.local/state/Discord
```

4. Remove any system-wide installation directories (if present):

```bash
sudo rm -rf /opt/discord
```

5. Remove any old desktop entry files:

```bash
rm -f ~/.local/share/applications/discord.desktop
```

6. Reinstall Discord:

```bash
sudo pacman -S discord
```

7. Force Discord to skip its internal host update:

Create or edit the file:

```bash
~/.config/discord/settings.json
```

Add the following content:

```json
{
  "SKIP_HOST_UPDATE": true
}
```

8. Temporary test to confirm it works (run from terminal):

```bash
QT_QPA_PLATFORM=xcb discord
```

9. Fix desktop entry:

Copy the system-wide desktop file to your local directory:

```bash
cp /usr/share/applications/discord.desktop ~/.local/share/applications/
```

Edit `~/.local/share/applications/discord.desktop`, change the `Exec=` line to:

```bash
Exec=env QT_QPA_PLATFORM=xcb /usr/bin/discord
```

Save the file and update the desktop database:

```bash
update-desktop-database ~/.local/share/applications/
```


## Extra: Gamma, Contrast and Saturation

Most in-game settings let you tweak gamma/contrast, but **saturation** is trickier on Linux.

### Options:

- Use monitor hardware controls (annoying but reliable)
- Try tools like:
  - `gamescope` (if supported)
  - `xrandr` (less useful on Wayland)
  - Color profiles (ICC) or HDR LUTs if you want to go deeper

---
