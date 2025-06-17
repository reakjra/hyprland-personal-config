Remember coolbits, permissions and exec-once

(hyprlock nvidia bypass fix + scripts)

```sh
env = WLR_NO_HARDWARE_CURSOR,1
env = __GL_VRR_RATE,0
env = LIBVA_DRIVER_NAME,nvidia


exec = ~/gpu-limit.sh

exec-once = dbus-update-activation-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

exec-once = bash -c "sleep 1 && xhost +si:localuser:root && sleep 2 && /home/nxjira/nvidia_fan_control.sh &"``
