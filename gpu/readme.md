<h1>Guide</h1>
<h2>1. Update the system</h2>

```yaml
sudo pacman -Syu
```
<h2>2. Scripts</h2>

Download the scripts files and place them in 
```yaml
~/
```
Then, make them a runnable script
```yaml
sudo chmod +x ~/nvidia_fan_control.sh
sudo chmod +x ~/gpu-limit.sh
```
<h2>3. Add sudoers</h2>

Update sudoers permissions to make the scripts run automatically without requiring any password which may block them from running.

```yaml
sudo nano /etc/sudoers.d/gpucontrol
```
then add
```yaml
<username> ALL=(ALL) NOPASSWD: /usr/bin/nvidia-settings
<username> ALL=(ALL) NOPASSWD: /usr/bin/nvidia-smi
<username> ALL=(ALL) NOPASSWD: /usr/bin/env
```
<h2>4. Install and set Nvidia utils and xhost</h2>

Download Nvidia Utils and xorg-xhost:
```yaml
sudo pacman -S nvidia nvidia-utils nvidia-settings xorg-xhost
```
Now, proceed to use xhost, open nvidia-settings and enable fun curve:
```yaml
xhost +si:localuser:root
sudo nvidia-settings
```
<h2>5. Enable CoolBits for Nvidia and add the scripts in hyprland.conf</h2>

First we add CoolBits to Nvidia configuration:
```yaml
sudo nano /etc/X11/xorg.conf.d/20-nvidia.conf
```
then add: 
```sh
Section "Device"
    Identifier "Nvidia Card"
    Driver "nvidia"
    Option "CoolBits" "4" # Or "8", "12", "28" for more features. "4" is usually enough for fan control.
EndSection
```
then, once done and assured everything else is done and working, we add the `exec-once` to the `hyprland.conf` file, assuring everything runs when booting.
```yaml
sudo nano ~/.config/hypr/hyprland.conf
```
add: 
```sh
exec = ~/gpu-limit.sh
exec-once = bash -c "sleep 1 && xhost +si:localuser:root && sleep 2 && /home/<username>/nvidia_fan_control.sh &"
```


<h2>+___+</h2>

if there's any login issue, it's probably due the SDDM having troubles with Nvidia (especially Candy), try to add this in the `hyprland.conf`:
```sh
env = WLR_NO_HARDWARE_CURSOR,1
env = __GL_VRR_RATE,0
env = LIBVA_DRIVER_NAME,nvidia

exec-once = dbus-update-activation-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
```
