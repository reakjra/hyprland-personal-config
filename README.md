# 🛠️ Hyprland (HyDE) Config - My Personal Linux Setup

Welcome to my personal configuration and survival guide for setting up Hyprland (HyDE) and gaming-related tweaks on Arch-based systems (EndeavourOS).  
This README includes tips, scripts, and setup instructions that I've collected to help me rebuild my setup quickly whenever needed.

```sh
EndeavourOS 
32GB RAM
3060 Ti
i5-13600K
```

> Mind I'm not an expert and neither experienced in any form of Linux. This repository is made primarily for myself. You might find several typos, grammatical errors and flawed english

---

## 📚 Table of Contents

- [⌨️ US INTL. Layout](#us-intl-layout)
- [📦 Mounting NTFS Drives](#mounting-ntfs-drives)
- [🖥️ GRUB Resolution Fix](#grub-resolution-fix)
- [❄️ Undervolting NVIDIA](https://github.com/reakjra/hyprland-config/blob/main/gpu/readme.md)
- [🕛 Date & Time Fix for Dual Boot](#date--time-fix-for-dual-boot)
- [🗣️ Discord Update & White Screen Fix](#discord-update--white-screen-fix)
- [🎮 lib32* games fixes](#lib32-fixes)
- [🌈 Extra: Gamma, Contrast and Saturation](#extra-gamma-contrast-and-saturation)
- [🎮 Gaming Related](https://github.com/reakjra/hyprland-config/blob/main/gaming/readme.md)
- [🌸 Setting up WM](#setting-up-wm)
- [🌸 Scripts](https://github.com/reakjra/hyprland-config/blob/main/scripts/)

---

## US INTL. Layout

Since it seems HyDE doesn´t apply the US INTL. Layout I need: 
```sh
sudo nano ~/.config/hypr/userprefs.conf


input {
     kb_layout = us
     kb_variant = intl
}
```

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

Discord sometimes asks for an update to version `0.0.0.100` and then shows a completely white window. Reinstalling doesn't fix it.
Fix steps:

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

---

## lib32 fixes

In some games (like Resident Evil 2 Remake & Days Gone Remastered) you may encounter a bunch of troubles. Like crashing after cutscenes or the game being completely unstable. That can be fixed with: 

```bash
yay -S lib32-gstreamer lib32-gst-plugins-base lib32-gst-plugins-good lib32-gst-plugins-bad lib32-gst-plugins-ugly \
       lib32-libva lib32-libx264 lib32-libvpx lib32-libmpeg2 lib32-openal \
       lib32-libpulse lib32-ffmpeg lib32-vulkan-icd-loader
```
> Mind it may take a lot to process.


## Extra: Gamma, Contrast and Saturation

Most in-game settings let you tweak gamma/contrast, but **saturation** is trickier on Linux.

### Options:

- Use monitor hardware controls (annoying but reliable)
- Try tools like:
  - `gamescope` (if supported)
  - `xrandr` (less useful on Wayland)
  - Color profiles (ICC) or HDR LUTs if you want to go deeper

---


## Setting up WM

> This section is tied to my personal preferences for my machine.

basic explaination: 

```sh
workspace 1: Steam Big Picture
workspace 2: Discord
workspace 3: Firefox
```

Since I'm using HyDE dotfiles, I'm gonna edit this file:

```sh
sudo nano ~/.config/hypr/userprefs.conf


# -----------------------------------------------------
# AUTORUN APPLICATIONS AND ASSIGN TO WORKSPACES AT BOOT
# -----------------------------------------------------

# Workspace 1: Steam Big Picture Mode

exec-once = [workspace 1 silent] steam -bigpicture
windowrule = fullscreen, class:^Steam$ # Ensure Steam Big Picture is fullscreen
windowrulev2 = workspace 1, class:^(steam_app_.*)$ # This will keep any game running in the first workspace along Steam even if you're working on another workspace.


windowrulev2 = workspace 2 silent, class:^(discord)$
exec-once = sh -c 'sleep 5 && discord'

exec-once = [workspace 3 silent] firefox
```

> The core idea is to make the gaming library all inside Steam. If it is needed to run something through Bottles, Lutris, etc. I´d add a non-Steam game into Steam's library and target it with the needed cli.



