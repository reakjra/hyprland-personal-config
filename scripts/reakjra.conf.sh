#!/bin/bash

#TODO: default package installer: Gwenview, mpv, Ark, Kate

# Pretty colors & format
GREEN="\e[32m"
RED="\e[31m"
BLUE='\e[34m'
CYAN="\e[36m"
YELLOW="\e[33m"
PINK="\e[38m"
RESET="\e[0m"
BOLD='\e[1m'
DIM='\e[2m'


LOG_DIR="$HOME/reakjra-CC-logs"

pause() {
  echo ""
  read -p "🌸 Press enter to return to the menu..."
  echo ""
}

##################################### ✨ MAIN MENU
main_menu() {
  clear
  echo -e "${RED}🌸 Welcome to Reakjra's personal EndeavourOS configuration script! 🌸${RESET}"
  echo ""
  echo "1. 📁 Mount partitions (NTFS)"
  echo "2. 🕒 Fix dual boot time issue"
  echo "3. 🧏🏻‍♀️ Install Discord with fix"
  echo "4. 🎵 Spotify & Spicetify Patch"
  echo "5. 🍿 Install Ani-cli, Aw-cli & Anime4K shaders"
  echo "6. 🎮 Install Steam, Bottles and GE-Proton"
  echo "7. 🎮 Install MangoHud and vkBasalt with configs"
  echo "8. 🎮 Install lib32* Multimedia"
  echo "9. 🎮 Install Gamemode and apply"
  echo "10. 🥚 Nvidia Configuration"
  echo "11. 🧹 Cleaner and Maintanance"
  echo "12. 🌸 HyDE/Hypr Personal Settings"
  echo "13. ❌ Exit"
  echo ""

  read -p "👉 Select an option (1-13): " choice
  case $choice in
  1) mount_drives_section ;;
  2) fix_dualboot_time ;;
  3) install_discord_with_fix ;;
  4) install_spotify_spicetify ;;
  5) install_ani_aw_cli_section ;;
  6) install_gaming_section ;;
  7) install_gaming_monitoring_tools ;;
  8) install_lib32_multimedia ;;
  9) install_gamemode_section ;;
  10) nvidia_menu ;;
  11) cleaner_menu ;;
  12) wm_settings_menu ;;
  13)
    echo "👋 Goodbye!"
    exit 0
    ;;
  *)
    echo "❌ Invalid choice."
    pause
    ;;
  esac
}


##################################### 🌸 MOUNT NTFS PARTITIONS
mount_drives_section() {
    echo ""
    read -p "📦 Do you want to proceed with the partition mounting section? (y/n): " do_mount
    [[ "$do_mount" != "y" ]] && return

    echo "🔍 Scanning for available partitions..."
    mapfile -t PARTS < <(lsblk -P -o NAME,SIZE,UUID,FSTYPE,MOUNTPOINT,TYPE)

    echo ""
    clear
    echo -e "🌸${RED} Mounting Drives 🌸 ${RESET}"
    echo ""
    echo "📁 Available partitions:"
    INDEXED_PARTS=()
    index=1

    for line in "${PARTS[@]}"; do
        eval "$line"
        [[ "$TYPE" != "part" ]] && continue

        mount_status=""
        [[ -n "$MOUNTPOINT" ]] && \
        mount_status="🌸 Already mounted → $([[ "$MOUNTPOINT" == "/" ]] && echo "/" || echo "$MOUNTPOINT")"

        UUID="${UUID:-N/A}"
        FSTYPE="${FSTYPE:-unknown}"

        printf "%2d. %-15s %-8s UUID: %-36s Type: %-8s  %s\n" \
            "$index" "$NAME" "$SIZE" "$UUID" "$FSTYPE" "$mount_status"

        INDEXED_PARTS+=("$NAME|$UUID|$FSTYPE|$MOUNTPOINT")
        ((index++))
    done

    [[ "${#INDEXED_PARTS[@]}" -eq 0 ]] && echo "🚫 No usable partitions found." && return

    echo ""
    echo -e "${RED}🌸 This uses the kernel driver 'ntfs3' to mount NTFS partitions. ${RESET}"
    echo -e "${RED}🌸 Keep in mind partition names can change due to boot order.${RESET}"
    echo ""
    read -p "👉 Enter the partition numbers to mount (e.g. 1,3,4): " selections

    IFS=',' read -ra SELECTED <<< "$selections"
    for sel in "${SELECTED[@]}"; do
        idx=$((sel - 1))
        [[ -z "${INDEXED_PARTS[$idx]}" ]] && echo "⚠️ Partition $sel is invalid, skipping." && continue

        IFS="|" read -r name uuid fstype mountpoint <<< "${INDEXED_PARTS[$idx]}"
        dev="/dev/$name"

        echo ""
        [[ -n "$mountpoint" ]] && echo "" && echo "⚠️ $name is already mounted at $mountpoint. Skipping." && continue
        echo ""

        read -p "🆔 Enter a custom mount name for $name (leave empty to use '$name'): " custom_name
        mount_name="${custom_name:-$name}"
        mount_dir="/mnt/$mount_name"

        echo "🔗 Mounting $name to $mount_dir..."
        sudo mkdir -p "$mount_dir"

        if [[ "$fstype" == "ntfs" ]]; then
            if ! sudo mount -t ntfs3 -o uid=$(id -u),gid=$(id -g) "$dev" "$mount_dir"; then
                echo "❌ Mount failed for $name."
                echo "ℹ️  Checking kernel log (last lines):"
                sudo dmesg | tail -n 50
                echo ""
                echo "👉 If you see 'volume is dirty' or 'hibernated', boot into Windows and run:"
                echo "   chkdsk X: /f on the corresponding drive letter, then fully shut down."
                echo "   Also consider disabling Fast Boot."
                continue
            fi
        else
            if ! sudo mount "$dev" "$mount_dir"; then
                echo "❌ Mount failed for $name."
                sudo dmesg | tail -n 50
                continue
            fi
        fi

        echo ""
        read -p "📝 Add $name to /etc/fstab for auto-mount on boot? (y/n): " add_fstab
        if [[ "$add_fstab" == "y" ]]; then
            if [[ "$fstype" == "ntfs" ]]; then
                echo ""
                echo "Choose ownership mode for fstab entry:"
                echo "  1) User (current UID/GID, readable by others)  -> uid=\$(id -u),gid=\$(id -g),umask=022"
                echo "  2) Root (world-writable for everyone)          -> umask=000"
                read -p "👉 Enter 1 or 2: " own_choice

                if [[ "$own_choice" == "2" ]]; then
                    new_line="UUID=${uuid} /mnt/${mount_name} ntfs3 defaults,rw,user,exec,umask=000 0 0"
                else
                    uid_now=$(id -u)
                    gid_now=$(id -g)
                    new_line="UUID=${uuid} /mnt/${mount_name} ntfs3 defaults,uid=${uid_now},gid=${gid_now},rw,user,exec,umask=022 0 0"
                fi
                existing_lines="$(grep -n "UUID=${uuid}" /etc/fstab || true)"
                if [[ -n "$existing_lines" ]]; then
                    echo ""
                    echo "⚠️ An entry with this UUID alrready exists in /etc/fstab:"
                    echo "$existing_lines"
                    echo ""
                    echo "Choose how to proceed:"
                    echo "  r) Replace all existing lines for this UUID"
                    echo "  c) Continue and append a new line anyway"
                    echo "  s) Skip writing to /etc/fstab"
                    read -p "👉 Enter r/c/s: " conflict_choice

                    case "$conflict_choice" in
                        r|R)
                            sudo sed -i "\|UUID=${uuid}|c ${new_line}" /etc/fstab
                            echo "✅ Replaced existing entry(ies) for UUID ${uuid}."
                            ;;
                        c|C)
                            echo "$new_line" | sudo tee -a /etc/fstab > /dev/null
                            echo "✅ Appended new entry to /etc/fstab."
                            ;;
                        *)
                            echo "↩️ Skipped editing /etc/fstab."
                            ;;
                    esac
                else
                    echo "$new_line" | sudo tee -a /etc/fstab > /dev/null
                    echo "✅ Added to /etc/fstab"
                fi
            else
                new_line="UUID=${uuid} /mnt/${mount_name} ${fstype} defaults 0 0"
                existing_lines="$(grep -n "UUID=${uuid}" /etc/fstab || true)"
                if [[ -n "$existing_lines" ]]; then
                    echo ""
                    echo "⚠️ An entry with this UUID alrready exists in /etc/fstab:"
                    echo "$existing_lines"
                    echo ""
                    echo "Choose how to proceed:"
                    echo "  r) Replace all existing lines for this UUID"
                    echo "  c) Continue and append a new line anyway"
                    echo "  s) Skip writing to /etc/fstab"
                    read -p "👉 Enter [r/c/s]: " conflict_choice

                    case "$conflict_choice" in
                        r|R) sudo sed -i "\|UUID=${uuid}|c ${new_line}" /etc/fstab; echo "✅ Replaced existing entry(ies).";;
                        c|C) echo "$new_line" | sudo tee -a /etc/fstab > /dev/null; echo "✅ Appended new entry.";;
                        *)   echo "↩️ Skipped editing /etc/fstab.";;
                    esac
                else
                    echo "$new_line" | sudo tee -a /etc/fstab > /dev/null
                    echo "✅ Added to /etc/fstab"
                fi
            fi
            echo ""
        fi
    done

    echo ""
    echo "🌹 Partition mounting section completed!"
    pause
}




##################################### 🌸 INSTALL STEAM, BOTTLES AND GE-PROTON
install_gaming_section() {
  echo ""
  read -p "🎮 Do you want to install Steam, Bottles and GE-Proton? (y/n): " confirm
  [[ "$confirm" != "y" ]] && return

  echo "🔍 Checking for installed components..."

  # Check Steam
  if command -v steam &>/dev/null; then
    echo "✅ Steam is already installed."
  else
    echo "📦 Installing Steam..."
    sudo pacman -S --noconfirm steam
  fi

  # Check Bottles
  if command -v bottles &>/dev/null; then
    echo "✅ Bottles is already installed."
  else
    echo "📦 Installing Bottles..."
    yay -S --noconfirm bottles
  fi

  echo "🌐 Fetching latest GE-Proton release..."

  mkdir -p ~/.local/share/Steam/compatibilitytools.d
  mkdir -p ~/.local/share/bottles/runners

  latest_url=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest |
    grep "browser_download_url" | grep ".tar.gz" | cut -d '"' -f 4 | head -n 1)

  [[ -z "$latest_url" ]] && echo -e "${RED}❌ Could not fetch GE-Proton URL.${RESET}" && return

  echo "⬇️  Downloading from $latest_url"
  wget "$latest_url" -P /tmp
  tarball_name=$(basename "$latest_url")
  ge_dir="${tarball_name%.tar.gz}"

  echo "📦 Extracting $tarball_name..."
  tar -xvf "/tmp/$tarball_name" -C /tmp

  echo "📁 Copying GE-Proton to Steam and Bottles directories..."
  cp -r "/tmp/$ge_dir" ~/.local/share/Steam/compatibilitytools.d/
  cp -r "/tmp/$ge_dir" ~/.local/share/bottles/runners/

  echo -e "${GREEN}✅ GE-Proton installed successfully!${RESET}"
  pause
}

##################################### 🌸  FIX DUAL BOOT TIME
fix_dualboot_time() {
  echo ""
  read -p "🕒 Do you want to fix the dual boot time issue (Linux vs Windows clock)? (y/n): " confirm
  [[ "$confirm" != "y" ]] && return

  sudo timedatectl set-local-rtc 1 --adjust-system-clock
  echo -e "${GREEN}✅ System clock set to local time. (Fixes time conflict with Windows!)${RESET}"
  pause
}

# 🌸  INSTALL MANGOHUD & VKBASALT WITH CUSTOM CONFIGS
install_gaming_monitoring_tools() {
  echo ""
  read -p "📊 Do you want to install MangoHud and vkBasalt with custom configs? (y/n): " confirm
  [[ "$confirm" != "y" ]] && return

  if command -v mangohud &>/dev/null; then
    echo "✅ MangoHud is already installed."
  else
    echo "📦 Installing MangoHud..."
    sudo pacman -S --noconfirm mangohud
  fi

  if command -v vkBasalt &>/dev/null; then
    echo "✅ vkBasalt is already installed."
  else
    echo "📦 Installing vkBasalt..."
    yay -S --noconfirm vkbasalt
  fi

  mkdir -p ~/.config/MangoHud
  mango_dir="$HOME/.config/MangoHud"
  mango_conf="$mango_dir/MangoHud.conf"

  if [[ -f "$mango_conf" ]]; then
    echo ""
    echo "⚠️ MangoHud config already exists."
  fi

  echo ""
  echo "🛠️ Choose MangoHud config type:"
  echo "1) Minimal"
  echo "2) Full"
  echo "3) Dynamic (switch between Minimal/Full)"
  read -p "Enter your choice (1/2/3): " config_choice

  if [[ "$config_choice" == "1" ]]; then
    echo "📝 Creating Minimal MangoHud config..."
    cat <<'EOF' >"$mango_conf"
# Appearance
engine_version=0
position=top-center
font_size=15
horizontal
background_alpha=0.0
text_color=FFFFFF
alpha=1
engine_color=FFFFFF

# Enabled Metrics
fps=1
gpu_stats=1
gpu_temp=1

# Custom Layout
text_layout=top-center
text=$fps | $gpu_temp

gpu_list=0

# Performance Metrics (disabled by default)
frametime=0
frame_timing=0
time=0
ram=0
vram=0
cpu_stats=0
cpu_temp=0
gpu_core_clock=0
gpu_mem_clock=0
gpu_power=0
EOF
    echo "✅ MangoHud config created."
  elif [[ "$config_choice" == "2" ]]; then
    echo "📝 Creating Full MangoHud config..."
    cat <<'EOF' >"$mango_conf"
# General Display Settings
position=top-left
font_size=24
alpha=0.9
background_alpha=0.5
text_color=FFFFFF
gpu_color=00FF00
cpu_color=00FFFF
frametime_color=FFFF00
engine_color=FF00FF

# Performance Metrics
fps
frame_timing
time
time_format=%H:%M:%S
ram
vram
cpu_stats
cpu_temp
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
gpu_power

# Layout
hud_layout=
${cpu_stats} CPU: ${cpu_temp}C (${cpu_power}W)
${core_freq}
${gpu_stats} GPU: ${gpu_temp}C (${gpu_power}W) Fan: ${gpu_fan}
${gpu_core_clock} / ${gpu_mem_clock}
FPS: ${fps}
${frame_timing}
RAM: ${ram} / VRAM: ${vram}
EOF
    echo "✅ MangoHud config created."
  else
    echo "📝 Creating Dynamic MangoHud profiles..."
    minimal_path="$mango_dir/mangohud-minimal.conf"
    full_path="$mango_dir/mangohud-full.conf"
    cat <<'EOF' >"$full_path"
# General Display Settings
position=top-left
font_size=24
alpha=0.9
background_alpha=0.5
text_color=FFFFFF
gpu_color=00FF00
cpu_color=00FFFF
frametime_color=FFFF00
engine_color=FF00FF

# Performance Metrics
fps
frame_timing
ram
vram
cpu_stats
cpu_temp
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
gpu_power

# Layout
hud_layout=
${cpu_stats} CPU: ${cpu_temp}C (${cpu_power}W)
${core_freq}
${gpu_stats} GPU: ${gpu_temp}C (${gpu_power}W) Fan: ${gpu_fan}
${gpu_core_clock} / ${gpu_mem_clock}
FPS: ${fps}
${frame_timing}
RAM: ${ram} / VRAM: ${vram}

reload_cfg=Shift_R+F10
EOF
    cat <<'EOF' >"$minimal_path"
legacy_layout=false

horizontal
background_alpha=0.0
round_corners=10
background_color=000000
background_alpha=0.0

font_size=14
text_color=FFFFFF
position=top-left

hud_compact
pci_dev=0:03:00.0
table_columns=1
gpu_text=G
gpu_stats
gpu_temp
gpu_color=2E9762
cpu_text=c
cpu_stats

frametime=0

cpu_temp
cpu_color=2E97CB
fps
fps_limit_method=late
toggle_fps_limit=Shift_L+F1

fps_limit=0
#offset=0


output_folder=/home/reakjra/
log_duration=30
autostart_log=0
blacklist=protonplus,lsfg-vk-ui,bazzar,gnome-calculator,pamac-manager,lact,ghb,bitwig-studio,ptyxis,yumex
log_interval=100
toggle_logging=Shift_L+F2
reload_cfg=Shift_R+F10
EOF
    ln -s ~/.config/MangoHud/mangohud-minimal.conf ~/.config/MangoHud/MangoHud.conf 2>/dev/null || ln -sfn "$minimal_path" "$mango_conf"
    switcher="$mango_dir/switch_mangohud.sh"
    cat <<'EOF' >"$switcher"
#!/bin/bash
set -euo pipefail
CONFIG_DIR="$HOME/.config/MangoHud"
ACTIVE="$CONFIG_DIR/MangoHud.conf"
MINIMAL="$CONFIG_DIR/mangohud-minimal.conf"
FULL="$CONFIG_DIR/mangohud-full.conf"
CURRENT=$(readlink "$ACTIVE" || true)
if [[ "$CURRENT" == "$MINIMAL" ]]; then
    ln -sfn "$FULL" "$ACTIVE"
    notify-send "MangoHud" "✨ Config: FULL"
else
    ln -sfn "$MINIMAL" "$ACTIVE"
    notify-send "MangoHud" "🌙 Config: MINIMAL"
fi
EOF
    chmod +x "$switcher"
    echo "✅ Dynamic profiles created. Default is MINIMAL."
    echo ""
    read -p "⛓️ Do you want to add a Hyprland shortcut to toggle configs? (y/n): " add_key
    echo ""
    if [[ "$add_key" == "y" ]]; then
      kb_line='bindn = RSHIFT, F10, exec, ~/.config/MangoHud/switch_mangohud.sh # MangoHud layout switch'
      target=""
      file1="$HOME/.config/hypr/custom/keybinds.conf"
      file2="$HOME/.config/hypr/userprefs.conf"
      file3="$HOME/.config/hypr/hyprland.conf"
      if [[ -f "$file1" ]]; then
        target="$file1"
        echo "Found End-4 dotfiles. Using $target"
      elif [[ -f "$file2" ]]; then
        target="$file2"
        echo "Found HyDE dotfiles. Using $target"
      else
        target="$file3"
        mkdir -p "$(dirname "$target")"
        [[ -f "$target" ]] || touch "$target"
        echo "Using default Hyprland config at $target"
      fi
      if grep -Fqx "$kb_line" "$target"; then
        echo "Keybind already present."
        echo ""
      else
        { echo ""; echo "$kb_line"; } >> "$target"
        echo ""
        echo "✅ Keybind added to $target"
        echo ""
      fi
    fi
  fi

  mkdir -p ~/.config/vkBasalt
  vk_conf=~/.config/vkBasalt/vkBasalt.conf
  if [[ -f "$vk_conf" ]]; then
    echo "⚠️ vkBasalt config already exists, skipping creation."
  else
    echo "📝 Creating vkBasalt config..."
    cat <<'EOF' >"$vk_conf"
# vkBasalt configuration file
effects = cas
cas = 0.1
toggleKey = 59
EOF
    echo "✅ vkBasalt config created."
  fi

  echo ""
  echo -e "${GREEN}🎉 MangoHUD and vkBasalt installed and configured!${RESET}"
  pause
}


##################################### 🌸 Install Discord with fix
install_discord_with_fix() {
  echo ""
  read -p "💬 Do you want to install Discord? (y/n): " confirm
  [[ "$confirm" != "y" ]] && return

  if command -v discord &>/dev/null; then
    echo "✅ Discord is already installed."
  else
    echo "📦 Installing Discord..."
    sudo pacman -S --noconfirm discord
  fi

  echo ""

  if ! command -v jq &>/dev/null; then
    echo "⚠️ 'jq' is required for editing settings.json. Installing..."
    sudo pacman -S --noconfirm jq
  fi

  echo ""
  read -p "🛠️ Do you want to apply the white update screen fix? (y/n): " apply_fix
  [[ "$apply_fix" != "y" ]] && pause && return

  echo "🔧 Applying Discord white screen fix..."

  # --- Fix 1: Modify settings.json ---
  config_dir="$HOME/.config/discord"
  settings_file="$config_dir/settings.json"

  mkdir -p "$config_dir"

  if [[ -f "$settings_file" ]]; then
    if grep -q '"SKIP_HOST_UPDATE": true' "$settings_file"; then
      echo "✅ 'SKIP_HOST_UPDATE' already set in settings.json"
    else
      echo "✏️ Patching settings.json..."
      tmp_file=$(mktemp)
      jq '. + {"SKIP_HOST_UPDATE": true}' "$settings_file" >"$tmp_file" && mv "$tmp_file" "$settings_file"
    fi
  else
    echo "📝 Creating settings.json..."
    cat <<EOF >"$settings_file"
{
  "SKIP_HOST_UPDATE": true
}
EOF
  fi

  # --- Fix 2: Modify local desktop entry ---
  desktop_dir="$HOME/.local/share/applications"
  desktop_file="$desktop_dir/discord.desktop"

  mkdir -p "$desktop_dir"
  cp /usr/share/applications/discord.desktop "$desktop_file" 2>/dev/null

  if [[ -f "$desktop_file" ]]; then
    sed -i 's|^Exec=.*|Exec=env QT_QPA_PLATFORM=xcb /usr/bin/discord|' "$desktop_file"
    echo "✅ desktop file updated."
  else
    echo "⚠️ Could not find system discord.desktop to copy."
  fi

  echo "🔄 Updating desktop database..."
  update-desktop-database "$desktop_dir"

  echo -e "${GREEN}🎉 Discord is installed and fixed!${RESET}"
  pause
}

##################################### 🌸 SPOTIFY & SPICETIFY
install_spotify_spicetify() {
  echo ""
  echo "🎵 This will install Spotify and patch it using Spicetify CLI + Marketplace."
  read -p "Continue? (y/n): " confirm
  [[ "$confirm" != "y" ]] && return

  echo "📦 Installing Spotify and Spicetify CLI..."
  yay -S spotify --noconfirm
  yay -S spicetify-cli --noconfirm

  echo "🔧 Applying permissions to /opt/spotify..."
  sudo chmod a+wr /opt/spotify
  sudo chmod a+wr /opt/spotify/Apps -R

  echo "🌐 Installing Spicetify Marketplace..."
  curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh

  echo "🛠️ Running spicetify backup + apply..."
  spicetify backup apply

  echo "✅ Spotify and Spicetify successfully installed and patched!"
  pause
}

##################################### 🌸 LIB32 MULTIMEDIA
install_lib32_multimedia() {
  echo ""
  echo "🎮 This will install essential lib32 multimedia libraries for better audio/video support in some games."
  echo "⚠️ This is especially useful for games like Resident Evil 2 Remake and Days Gone Remastered."
  echo "⏳ The installation can take a while (~30 minutes depending on your system and internet speed)."
  read -p "Do you want to continue? (y/n): " confirm
  [[ "$confirm" != "y" ]] && return

  yay -S lib32-gstreamer lib32-gst-plugins-base lib32-gst-plugins-good lib32-gst-plugins-bad lib32-gst-plugins-ugly \
    lib32-libva lib32-libx264 lib32-libvpx lib32-libmpeg2 lib32-openal \
    lib32-libpulse lib32-ffmpeg lib32-vulkan-icd-loader --noconfirm

  echo "✅ All lib32 multimedia libraries have been installed."
  pause
}

##################################### 🌸 INSTALL GAMEMODE
install_gamemode_section() {
  echo ""
  read -p "🌸 Do you want to install and configure Gamemode? (y/n): " confirm
  [[ "$confirm" != "y" ]] && return

  # Step 1: Install gamemode
  if command -v gamemoded &>/dev/null; then
    echo "✅ Gamemode is already installed."
  else
    echo "📦 Installing Gamemode..."
    sudo pacman -S --noconfirm gamemode lib32-gamemode
  fi

  # Step 2: Add user to gamemode group
  if groups $(whoami) | grep -qw "gamemode"; then
    echo "✅ You are already part of the 'gamemode' group."
  else
    echo "👥 Adding current user to 'gamemode' group..."
    sudo usermod -aG gamemode $(whoami)
    echo "✅ User added to 'gamemode' group."
  fi

  # Step 3: Check if gamemoded is running
  echo "🔍 Checking if gamemoded service is running..."
  if systemctl --user is-active --quiet gamemoded; then
    echo "✅ Gamemoded is running under user session."
  elif systemctl is-active --quiet gamemoded; then
    echo "✅ Gamemoded is running (system level)."
  else
    echo "⚠️ Gamemoded is not currently active."
    echo "⏳ Trying to start it manually..."
    systemctl --user start gamemoded 2>/dev/null || sudo systemctl start gamemoded

    if systemctl --user is-active --quiet gamemoded || systemctl is-active --quiet gamemoded; then
      echo "✅ Gamemoded started successfully!"
    else
      echo "⚠️ Could not start gamemoded. Try rebooting or launching it with 'gamemoded -d'."
    fi
  fi

  echo ""
  echo -e "${GREEN}🎉 Gamemode is installed and configured!${RESET}"
  pause
}


#################################### 🌸 INSTALL ANI-CLI, AW-CLI & ANIME4K SHADERS | This is so bad written : fix!!!
install_ani_aw_cli_section() {
 
  echo ""
  echo "😊 Checking for mpv..."

  # Check mpv
  if ! command -v mpv &>/dev/null; then
    echo "📦 mpv not found. Installing..."
    sudo pacman -S --noconfirm mpv
  else
    echo "✅ mpv is already installed."
  fi

  echo ""

  # ani-cli
  read -p "🎥 Install ani-cli (yay)? [y/n/s]: " ani
  if [[ "$ani" == "y" ]]; then
    yay -S --noconfirm ani-cli
  elif [[ "$ani" == "n" ]]; then
    echo "❌ Returning to menu..."
    pause
    return
  else
    echo "⏩ Skipping ani-cli."
  fi

  echo ""

  # pipx
  read -p "🧪 Install pipx (required for aw-cli)? [y/n/s]: " pipx_ans
  if [[ "$pipx_ans" == "y" ]]; then
    sudo pacman -S --noconfirm python-pipx
    pipx ensurepath
  elif [[ "$pipx_ans" == "n" ]]; then
    echo "❌ Returning to menu..."
    pause
    return
  else
    echo "⏩ Skipping pipx."
  fi

  echo ""

  # aw-cli
  read -p "🗣️ Install aw-cli (Italian subs)? [y/n/s]: " aw
  if [[ "$aw" == "y" ]]; then
    pipx install aw-cli
  elif [[ "$aw" == "n" ]]; then
    echo "❌ Returning to menu..."
    pause
    return
  else
    echo "⏩ Skipping aw-cli."
  fi

  echo ""

  # SSL key for aw-cli
  read -p "🔐 Add SSL certificate (required for aw-cli)? [y/n/s]: " ssl
  if [[ "$ssl" == "y" ]]; then
    cert_file="$HOME/SSL.com-TLS-T-ECC-R2.pem"
    curl -o "$cert_file" https://ssl.com/repo/certs/SSL.com-TLS-T-ECC-R2.pem
    sudo trust anchor "$cert_file"
    rm "$cert_file"
    echo "✅ Certificate added and cleaned up."
  elif [[ "$ssl" == "n" ]]; then
    echo "❌ Returning to menu..."
    pause
    return
  else
    echo "⏩ Skipping SSL cert."
  fi

  echo ""

  # Anime4K shaders
  read -p "🌟 Install Anime4K shaders and apply configs (will overwrite mpv configs)? [y/n/s]: " shaders
  if [[ "$shaders" == "s" ]]; then
    echo "⏩ Skipping Anime4K setup."
    pause
    return
  elif [[ "$shaders" != "y" ]]; then
    echo "❌ Returning to menu..."
    pause
    return
  fi

  echo ""
  echo "📦 Cloning Anime4K repo..."
  git clone https://github.com/bloc97/Anime4K.git ~/Anime4K

  echo ""
  shaders_dir="$HOME/.config/mpv/shaders"
  backup_dir="$HOME/.config/mpv/mpv_backup"
  mkdir -p "$shaders_dir" "$backup_dir"

  echo "🗄️ Backing up current mpv configs (if any)..."
  [[ -f "$HOME/.config/mpv/mpv.conf" ]] && cp "$HOME/.config/mpv/mpv.conf" "$backup_dir/"
  [[ -f "$HOME/.config/mpv/input.conf" ]] && cp "$HOME/.config/mpv/input.conf" "$backup_dir/"

  echo ""
  echo "🎨 Copying all .glsl shaders to ~/.config/mpv/shaders..."
  find ~/Anime4K/glsl/ -type f -name "*.glsl" -exec cp {} "$shaders_dir/" \;

  echo ""
  echo "📝 Writing new mpv.conf and input.conf..."

  cat > "$HOME/.config/mpv/mpv.conf" <<EOF
# Optimized shaders for lower-end GPU: Mode A (Fast)
glsl-shaders="~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"
EOF

  cat > "$HOME/.config/mpv/input.conf" <<EOF
# Optimized shaders for lower-end GPU:
CTRL+1 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode A (Fast)"
CTRL+2 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_Soft_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode B (Fast)"
CTRL+3 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode C (Fast)"
CTRL+4 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_Restore_CNN_S.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode A+A (Fast)"
CTRL+5 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Restore_CNN_Soft_M.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Restore_CNN_Soft_S.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode B+B (Fast)"
CTRL+6 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl:~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_M.glsl:~~/shaders/Anime4K_AutoDownscalePre_x2.glsl:~~/shaders/Anime4K_AutoDownscalePre_x4.glsl:~~/shaders/Anime4K_Restore_CNN_S.glsl:~~/shaders/Anime4K_Upscale_CNN_x2_S.glsl"; show-text "Anime4K: Mode C+A (Fast)"
CTRL+0 no-osd change-list glsl-shaders clr ""; show-text "GLSL shaders cleared"
EOF

  echo ""
  echo "🧹 Cleaning up ~/Anime4K repo..."
  rm -rf ~/Anime4K

  echo ""
  echo -e "${GREEN}🌸 Ani-cli, aw-cli, Anime4K shaders & mpv installed successfully!!!!!!!!!! ${RESET}"
  pause
}


#################################### 🌸 WM SETTINGS MENU
wm_settings_menu() {
  while true; do
    clear
    echo ""
    echo -e "🌸${RED} WM Personal Settings (HyDE only) 🌸 ${RESET} "
    echo ""
    echo "1. 🍼 Import userprefs.conf (it will override the current one)"
    echo "2. 🍼 Import windowrules.conf (it will override the current one)"
    echo "3. 🍼 Import Reakjra's Waybar settings"
    echo "4. 🍼 Apply wallbash theme to Visual Studio Code"
    echo "5. 👈 Back to main menu"
    echo ""
    read -p "Choose an option: " choice

    case "$choice" in
    1) update_userprefs ;;
    2) update_windowsrules ;;
    3) import_waybar ;;
    4) apply_wallbash_code_theme ;;
    5) break ;;
    *) echo "❌ Invalid option." ;;
    esac
  done
}

##################################### 🌸 WM SETTINGS: USERPREFS
update_userprefs() {
  echo -e "\n🌸 Updating userprefs.conf from remote GitHub repository..."

  TARGET="$HOME/.config/hypr/userprefs.conf"

  # Step 1: Check if file exists (HyDE check)
  if [[ ! -f "$TARGET" ]]; then
    echo "❌ userprefs.conf not found. You are likely not using HyDE."
    echo "Skipping this step."
    return
  fi

  echo "✅ userprefs.conf found. You are using HyDE."

  # Step 2: Ask for confirmation
  read -rp "Do you want to replace your current userprefs.conf with the one from GitHub? [Y/n]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ && -n "$confirm" ]]; then
    echo "❌ Aborted. Your current config was not changed."
    return
  fi

  # Step 3: Backup existing config
  TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
  BACKUP="${TARGET}.bak-${TIMESTAMP}"
  cp "$TARGET" "$BACKUP"
  echo "🗄️ Backup created at: $BACKUP"

  # Step 4: Download from GitHub
  GITHUB_URL="https://raw.githubusercontent.com/reakjra/hyprland-personal-config/refs/heads/main/scripts/HyDE/hypr/userprefs.conf"
  echo "⬇️ Downloading new config from GitHub..."

  if curl -fsSL "$GITHUB_URL" -o "$TARGET"; then
    echo "✅ userprefs.conf successfully updated!"
  else
    echo "❌ Failed to download the file. Reverting to your previous config."
    cp "$BACKUP" "$TARGET"
    echo "🔁 Reverted to: $BACKUP"
  fi
}

##################################### 🌸  UPDATE WINDOWRULES.CONF
update_windowsrules() {
  echo -e "\n🌸 Updating windowrules.conf from remote GitHub repository..."

  TARGET="$HOME/.config/hypr/windowrules.conf"

  # Step 1: Check if file exists (HyDE check)
  if [[ ! -f "$TARGET" ]]; then
    echo "❌ windowrules.conf not found. You are likely not using HyDE."
    echo "Skipping this step."
    return
  fi

  echo "✅ windowrules.conf found. You are using HyDE."

  # Step 2: Ask for confirmation
  read -rp "Do you want to replace your current windowrules.conf with the one from GitHub? [Y/n]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ && -n "$confirm" ]]; then
    echo "❌ Aborted. Your current windowrules.conf was not changed."
    return
  fi

  # Step 3: Backup existing config
  TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
  BACKUP="${TARGET}.bak-${TIMESTAMP}"
  cp "$TARGET" "$BACKUP"
  echo "🗄️ Backup created at: $BACKUP"

  # Step 4: Download from GitHub
  GITHUB_URL="https://raw.githubusercontent.com/reakjra/hyprland-personal-config/refs/heads/main/scripts/HyDE/hypr/windowrules.conf"
  echo "⬇️ Downloading new config from GitHub..."

  if curl -fsSL "$GITHUB_URL" -o "$TARGET"; then
    echo "✅ windowrules.conf successfully updated!"
  else
    echo "❌ Failed to download the file. Reverting to your previous config."
    cp "$BACKUP" "$TARGET"
    echo "🔁 Reverted to: $BACKUP"
  fi
}

##################################### 🌸 WM SETTINGS: IMPORT WAYBAR
import_waybar() {
  echo ""

  local confirm_import
  while true; do
    read -p "🌸 Do you want to import Reakjra's waybar settings? (y/n): " confirm_import
    case "$confirm_import" in
    [yY])
      break
      ;;
    [nN])
      echo "❌ Cancelled."
      pause
      return
      ;;
    *)
      echo "⚠️ Invalid input. Please enter 'y' or 'n'."
      ;;
    esac
  done

  echo ""

  GITHUB_USERNAME="reakjra"
  REPOSITORY_NAME="hyprland-personal-config"
  BRANCH_NAME="main"
  API_BASE_URL="https://api.github.com/repos/${GITHUB_USERNAME}/${REPOSITORY_NAME}/contents"
  RAW_BASE_URL="https://raw.githubusercontent.com/${GITHUB_USERNAME}/${REPOSITORY_NAME}/${BRANCH_NAME}"

  # --- Import Waybar Layout (reakjra.jsonc) ---
  echo -e "\n📄 Importing layout: reakjra.jsonc"
  layout_path="scripts/HyDE/waybar/reakjra.jsonc"
  layout_url="${RAW_BASE_URL}/${layout_path}"
  layout_target="$HOME/.local/share/waybar/layouts/hyprdots/reakjra.jsonc"

  if [[ -e "$layout_target" ]]; then
    local ow_layout
    while true; do
      read -p "❓ '$layout_target' already exists. Overwrite? (y/n): " ow_layout
      case "$ow_layout" in
      [yY])
        curl -sSL "$layout_url" -o "$layout_target" && echo "✅ Overwritten."
        break
        ;;
      [nN])
        echo "⏩ Skipped."
        break
        ;;
      *)
        echo "⚠️ Invalid input. Please enter 'y' or 'n'."
        ;;
      esac
    done
  else
    curl -sSL "$layout_url" -o "$layout_target" && echo "✅ Downloaded."
  fi

  # --- Import Waybar Modules (.jsonc) ---
  echo -e "\n📦 Importing all Waybar modules (.jsonc)..."
  modules_api_path="scripts/HyDE/waybar/modules"
  modules_api_url="${API_BASE_URL}/${modules_api_path}"
  modules_raw_dir="${RAW_BASE_URL}/${modules_api_path}"
  modules_target_dir="$HOME/.local/share/waybar/modules"

  # Fetch module files using GitHub API and jq
  echo "Fetching module list from: $modules_api_url"
  echo ""
  module_files=$(curl -sSL "$modules_api_url" | jq -r '.[] | select(.type=="file" and (.name | endswith(".jsonc"))) | .name' 2>/dev/null)

  if [ $? -ne 0 ] || [ -z "$module_files" ]; then
    echo "❌ Error: Could not fetch module list or 'jq' is not installed/path is incorrect. Please ensure 'jq' is installed."
    pause
    return
  fi

  for file in $module_files; do
    url="${modules_raw_dir}/${file}"
    target="${modules_target_dir}/${file}"
    echo "📄 Module: $file"
    if [[ -e "$target" ]]; then
      local ow_module
      while true; do
        read -p "❓ '$file' exists. Overwrite? (y/n): " ow_module
        case "$ow_module" in
        [yY])
          curl -sSL "$url" -o "$target" && echo "✅ Overwritten."
          break
          ;;
        [nN])
          echo "⏩ Skipped."
          break
          ;;
        *)
          echo "⚠️ Invalid input. Please enter 'y' or 'n'."
          ;;
        esac
      done
    else
      curl -sSL "$url" -o "$target" && echo "✅ Downloaded."
    fi
  done

  # --- Import Waybar Menus (.xml) ---
  echo -e "\n📂 Importing all menu files (.xml)..."
  menus_api_path="scripts/HyDE/waybar/menus"
  menus_api_url="${API_BASE_URL}/${menus_api_path}"
  menus_raw_dir="${RAW_BASE_URL}/${menus_api_path}"
  menus_target_dir="$HOME/.local/share/waybar/menus"

  # Fetch menu files using GitHub API and jq
  echo "Fetching menu list from: $menus_api_url"
  echo ""
  menu_files=$(curl -sSL "$menus_api_url" | jq -r '.[] | select(.type=="file" and (.name | endswith(".xml"))) | .name' 2>/dev/null)

  if [ $? -ne 0 ] || [ -z "$menu_files" ]; then
    echo "❌ Error: Could not fetch menu list or 'jq' is not installed/path is incorrect. Please ensure 'jq' is installed."
    pause
    return
  fi

  for file in $menu_files; do
    url="${menus_raw_dir}/${file}"
    target="${menus_target_dir}/${file}"
    echo "📄 Menu: $file"
    if [[ -e "$target" ]]; then
      local ow_menu
      while true; do
        read -p "❓ '$file' exists. Overwrite? (y/n): " ow_menu
        case "$ow_menu" in
        [yY])
          curl -sSL "$url" -o "$target" && echo "✅ Overwritten."
          break
          ;;
        [nN])
          echo "⏩ Skipped."
          break
          ;;
        *)
          echo "⚠️ Invalid input. Please enter 'y' or 'n'."
          ;;
        esac
      done
    else
      curl -sSL "$url" -o "$target" && echo "✅ Downloaded."
    fi
  done

  echo ""

  local confirm_run_waybar
  while true; do
    read -p "🌟 Do you want to run 'waybar.py -G' now? (y/n): " confirm_run_waybar
    case "$confirm_run_waybar" in
    [yY])
      waybar.py -G
      break
      ;;
    [nN])
      echo "⏩ Skipped 'waybar.py -G' command."
      break
      ;;
    *)
      echo "⚠️ Invalid input. Please enter 'y' or 'n'."
      ;;
    esac
  done

  echo -e "\n🌸 Done importing Reakjra's Waybar config!"
  pause
}

##################################### 🌸 APPLY WALLBASH THEME TO VISUAL STUDIO CODE
apply_wallbash_code_theme() {
  SCRIPT="$HOME/.config/hyde/wallbash/scripts/code.sh"

  echo -e "\n🌸 Applying Wallbash theme to Visual Studio Code..."

  # Check if the script exists
  if [[ ! -f "$SCRIPT" ]]; then
    echo "❌ Wallbash theme script for VS Code not found!"
    echo "Expected at: $SCRIPT"
    return
  fi

  # Confirm
  read -rp "Are you sure you want to apply the Wallbash theme to VS Code? [Y/n]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ && -n "$confirm" ]]; then
    echo "❌ Cancelled. VS Code theme was not changed."
    return
  fi

  # Run the script
  bash "$SCRIPT"

  # Feedback
  if [[ $? -eq 0 ]]; then
    echo "✅ Wallbash theme successfully applied to VS Code!"
  else
    echo "⚠️ Something went wrong while applying the theme."
  fi
}

##################################### 🌸 CLEANER MENU
cleaner_menu() {
  while true; do

    mkdir -p "$LOG_DIR"

    clear
    echo -e "${RED}🌸 Reakjra Cleaner - Clean & Maintain your system 🌸${RESET}"
    echo ""
    echo "1. 🗑️ Clean pacman cache"
    echo "2. 🧹 Clean yay cache"
    echo "3. 🧺 Remove orphaned packages"
    echo "4. 📦 Full system update"
    echo "5. 🔍 Check cache sizes"
    echo "6. 🧼 Delete leftover files from a package"
    echo "7. ♻️ Restore deleted files (from Trash)"
    echo "8. ♻️ Restore removed orphan packages"
    echo "9. 🎮 Clean steam prefixes (compatdata)"
    echo "10. ❌ Back to main menu"
    echo ""
    echo ""
    echo -e "${RED} 🌸 Careful! This tool is not completely safe, you might end up removing important files! ${RESET}"
    echo ""
    echo ""

    read -p "👉 Select an option: " choice
    case $choice in
    1) clean_pacman_cache ;;
    2) clean_yay_cache ;;
    3) remove_orphans ;;
    4) full_update ;;
    5) check_cache_sizes ;;
    6) clean_package_traces ;;
    7) restore_deleted_files ;;
    8) restore_orphans ;;
    9) cleaner_steam_prefixes_menu ;;
    10) break ;;
    *)
      echo "❌ Invalid choice."
      pause
      ;;
    esac
  done
}

####################################
clean_pacman_cache() {
  echo ""
  read -p "❓ Do you want to clean pacman cache? (y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    logfile="$LOG_DIR/clean_pacman_cache_$(date +%Y-%m-%dT%H-%M-%S).txt"
    sudo pacman -Sc --noconfirm | tee "$logfile"
    echo "📝 Log saved: $logfile"
  fi
  pause
}

####################################
clean_yay_cache() {
  echo ""
  read -p "❓ Do you want to clean yay cache? (y/n): " confirm
  if [[ "$confirm" == "y" ]]; then
    logfile="$LOG_DIR/clean_yay_cache_$(date +%Y-%m-%dT%H-%M-%S).txt"
    yay -Sc --noconfirm | tee "$logfile"
    echo "📝 Log saved: $logfile"
  fi
  pause
}

####################################
remove_orphans() {
  echo ""
  echo "🔍 Searching for orphaned packages..."
  orphans=$(pacman -Qtdq 2>/dev/null)
  if [[ -z "$orphans" ]]; then
    echo "✅ No orphaned packages found!"
  else
    echo "🧺 Orphans found:"
    echo "$orphans"
    read -p "❓ Remove them? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
      timestamp=$(date +%Y-%m-%dT%H-%M-%S)
      logfile="$LOG_DIR/remove_orphans_$timestamp.txt"
      echo "$orphans" >"$logfile"
      sudo pacman -Rns $orphans
      echo "📝 Orphan removal log saved at $logfile"
    fi
  fi
  pause
}

####################################
full_update() {
  echo ""
  echo "📦 Running full system update..."
  timestamp=$(date +%Y-%m-%dT%H-%M-%S)
  logfile="$LOG_DIR/full_update_$timestamp.txt"
  {
    sudo pacman -Syu --noconfirm
    yay -Syu --noconfirm
  } | tee "$logfile"
  echo "📝 Update log saved: $logfile"
  pause
}

check_cache_sizes() {
  echo ""
  echo "🔍 pacman cache:"
  du -sh /var/cache/pacman/pkg
  echo "🔍 yay cache:"
  du -sh ~/.cache/yay
  pause
}

##################################### 🌸 CLEAN SPECIFIC PACKAGE
clean_package_traces() {
  echo ""
  read -p "🌸 Enter the name of the package/app to clean: " pkg_name
  [[ -z "$pkg_name" ]] && echo "❌ No package entered." && pause && return

  forbidden=("/" "/boot" "/etc" "bin" "sbin" "lib" "usr" "var" "*" "root" "system")
  for word in "${forbidden[@]}"; do
    if [[ "$pkg_name" == *"$word"* ]]; then
      echo -e "${RED}❌ Dangerous package name. Aborting for safety.${RESET}"
      pause
      return
    fi
  done

  echo ""
  echo "🔍 Checking if '$pkg_name' is installed..."

  if pacman -Q "$pkg_name" &>/dev/null; then
    echo "📦 Package found via pacman."
    read -p "🗑️ Remove it with 'sudo pacman -Rns $pkg_name'? (y/n): " confirm
    [[ "$confirm" == "y" ]] && sudo pacman -Rns "$pkg_name"
  elif yay -Q "$pkg_name" &>/dev/null; then
    echo "📦 Package found via yay."
    read -p "🗑️ Remove it with 'yay -Rns $pkg_name'? (y/n): " confirm
    [[ "$confirm" == "y" ]] && yay -Rns "$pkg_name"
  elif paru -Q "$pkg_name" &>/dev/null; then
    echo "📦 Package found via paru."
    read -p "🗑️ Remove it with 'paru -Rns $pkg_name'? (y/n): " confirm
    [[ "$confirm" == "y" ]] && paru -Rns "$pkg_name"
  else
    echo "🔍 Not found in package managers. Skipping uninstall step."
  fi

  echo ""
  echo "🔍 Scanning for residual files..."
  results=$(find ~ -iname "*$pkg_name*" 2>/dev/null | grep -vE "^/boot|^/etc|^/bin|^/sbin|^/lib|^/usr|^/var|^/dev")

  if [[ -z "$results" ]]; then
    echo "✅ No leftovers found."
    pause
    return
  fi

  echo "📁 Found:"
  echo ""
  echo "$results"
  read -p "🧨 Move these to Trash? (y/n): " confirm
  [[ "$confirm" != "y" ]] && echo "❌ Cancelled." && pause && return

  trash_dir="$HOME/.local/share/Trash/files"
  mkdir -p "$trash_dir"
  timestamp=$(date +%Y-%m-%dT%H-%M-%S)
  logfile="$LOG_DIR/clean_package_traces_${pkg_name}_$timestamp.txt"
  touch "$logfile"

  echo "$results" | while read path; do
    if [[ -e "$path" ]]; then
      mv "$path" "$trash_dir/"
      echo "$path" >>"$logfile"
      echo "🧹 Moved to Trash: $path"
    fi
  done

  echo "📝 Log saved: $logfile"
  pause
}

####################################
restore_deleted_files() {
  log_dir="$LOG_DIR"
  trash_dir="$HOME/.local/share/Trash/files"

  logs=("$log_dir"/clean_package_traces_*.txt)
  [[ ${#logs[@]} -eq 0 ]] && echo "❌ No deleted file logs found." && return

  echo ""
  echo -e "${CYAN}♻️ Restore deleted files (from Trash) 🌸${RESET}"
  echo ""

  for i in "${!logs[@]}"; do
    echo "$((i + 1))) $(basename "${logs[$i]}")"
  done
  echo ""
  read -p "👉 Choose log(s) to restore (e.g. 1 or 1,2): " choice
  IFS=',' read -ra indexes <<<"$choice"

  for i in "${indexes[@]}"; do
    idx=$((i - 1))
    logfile="${logs[$idx]}"
    echo "🔄 Restoring from: $(basename "$logfile")"

    while IFS= read -r path; do
      base=$(basename "$path")
      dir=$(dirname "$path")
      mkdir -p "$dir"
      if [[ -e "$trash_dir/$base" ]]; then
        mv "$trash_dir/$base" "$dir/"
        echo "✅ Restored: $path"
      else
        echo "⚠️ Not in Trash: $base"
      fi
    done <"$logfile"
  done
  pause
}

####################################
restore_orphans() {
  logs=("$LOG_DIR"/remove_orphans_*.txt)
  [[ ${#logs[@]} -eq 0 ]] && echo "❌ No orphan logs found." && return

  echo ""
  echo -e "${CYAN}♻️ Restore orphaned packages 🌸${RESET}"
  echo ""

  for i in "${!logs[@]}"; do
    echo "$((i + 1))) $(basename "${logs[$i]}")"
  done

  echo ""
  read -p "👉 Choose log(s) to restore (e.g. 1 or 1,3): " choice
  IFS=',' read -ra indexes <<<"$choice"

  for i in "${indexes[@]}"; do
    idx=$((i - 1))
    logfile="${logs[$idx]}"
    echo "🔄 Reinstalling from: $(basename "$logfile")"
    while IFS= read -r pkg; do
      yay -S --needed --noconfirm "$pkg"
    done <"$logfile"
  done
  pause
}

#####################################
cleaner_steam_prefixes_menu() {
  command -v du >/dev/null || { printf "%s\n" "'du' is missing."; return; }
  command -v findmnt >/dev/null || { printf "%s\n" "'findmnt' is missing."; return; }
  command -v awk >/dev/null || { printf "%s\n" "'awk' is missing."; return; }

  local HAVE_CURL=0 HAVE_JQ=0 HAVE_NUMFMT=0
  command -v curl >/dev/null && HAVE_CURL=1
  command -v jq   >/dev/null && HAVE_JQ=1
  command -v numfmt >/dev/null && HAVE_NUMFMT=
  # are these checks even needed at this point...?

  clear
  printf "%b\n" "${RED}🌸 ${BOLD}Steam Proton prefixes — compatdata${RESET} ${RED}🌸${RESET}"
  printf "%b\n\n" "${DIM}Scanning all mounted partitions for SteamLibrary/steamapps/compatdata/<appid>${RESET}"

  local -a LIB_PATHS=()
  declare -A SEEN_LIB
  while IFS= read -r mp; do
    while IFS= read -r lib; do
      [[ -n "${SEEN_LIB[$lib]}" ]] && continue
      SEEN_LIB[$lib]=1
      LIB_PATHS+=("$lib")
    done < <(find "$mp" -maxdepth 3 -type d -name SteamLibrary 2>/dev/null)
  done < <(findmnt -rn -o TARGET)

  if ((${#LIB_PATHS[@]}==0)); then
    printf "%s\n" "No 'SteamLibrary' folders found."
    read -rp "Press Enter to go back... " _
    return
  fi

  human() { if ((HAVE_NUMFMT)); then numfmt --to=iec --suffix=B "$1" 2>/dev/null || printf "%sB" "$1"; else printf "%sB" "$1"; fi; }
  is_tool_like_name() { local nm="${1,,}"; [[ "$nm" =~ ^proton ]] && return 0; [[ "$nm" == *"runtime"* ]] && return 0; [[ "$nm" == *"compatibility tool"* ]] && return 0; return 1; }
  ellipsize() { local s="$1" w="${2:-40}"; (( ${#s} > w )) && printf "%s…" "${s:0:w-1}" || printf "%s" "$s"; }
  strip_symbols() { local s="$1"; s="${s//™/}"; s="${s//®/}"; s="${s//©/}"; s="${s//℠/}"; printf "%s" "$s"; }

  local -a IDX_PATH IDX_LABEL IDX_BYTES
  local idx=0
  local NAME_W=40
  local ID_W=8

  for lib in "${LIB_PATHS[@]}"; do
    local steamapps="$lib/steamapps"
    local compat="$steamapps/compatdata"
    [[ -d "$compat" ]] || continue

    local compat_total_h; compat_total_h=$(du -sh --apparent-size "$compat" 2>/dev/null | cut -f1)
    printf "%b\n" "${BLUE}🌸 ${lib} - [${compat_total_h}]${RESET}"

    shopt -s nullglob
    local -a LINES=()
    local d
    for d in "$compat"/*; do
      [[ -d "$d" ]] || continue
      local appid; appid=$(basename "$d")
      [[ "$appid" =~ ^[0-9]+$ ]] || continue

      local size_b size_h
      size_b=$(du -sb --apparent-size "$d" 2>/dev/null | cut -f1)
      size_h=$(du -sh --apparent-size "$d" 2>/dev/null | cut -f1)

      local name=""
      local manifest="$steamapps/appmanifest_${appid}.acf"
      if [[ -f "$manifest" ]]; then
        name=$(awk -F'"' '/"name"[[:space:]]*"/{print $4; exit}' "$manifest")
      fi
      local api_type=""
      if [[ -z "$name" && $HAVE_CURL -eq 1 && $HAVE_JQ -eq 1 ]]; then
        local json; json=$(curl -s "https://store.steampowered.com/api/appdetails?appids=${appid}&l=en")
        name=$(jq -r ".\"$appid\".data.name // empty" <<<"$json")
        api_type=$(jq -r ".\"$appid\".data.type // empty" <<<"$json")
      fi
      [[ -z "$name" ]] && name="Unknown app"
      [[ -n "$api_type" && "$api_type" != "game" ]] && continue
      is_tool_like_name "$name" && continue

      LINES+=("${size_b}"$'\t'"${name}"$'\t'"${appid}"$'\t'"${size_h}"$'\t'"${d}")
    done
    shopt -u nullglob

    if ((${#LINES[@]})); then
      while IFS=$'\t' read -r sb nm aid shh path; do
        local nm_disp; nm_disp=$(strip_symbols "$nm")
        local nm_show; nm_show=$(ellipsize "$nm_disp" "$NAME_W")
        local gap=$(( ID_W - ${#aid} ))
        (( gap < 0 )) && gap=0
        printf " %3d. %-*s (%s)%*s[%s]\n" \
          "$((idx+1))" "$NAME_W" "$nm_show" "$aid" "$gap" " " "$shh"
        IDX_PATH[$idx]="$path"
        IDX_LABEL[$idx]="$nm ($aid)"
        IDX_BYTES[$idx]="$sb"
        ((idx++))
      done < <(printf "%s\n" "${LINES[@]}" | sort -t $'\t' -k1,1nr)
    fi

    printf "\n"
  done

  ((idx==0)) && { printf "No game prefixes found.\n"; read -rp "Press Enter... " _; return; }

  printf "%s\n" "Select prefixes to delete (e.g: 1,4) — leave empty to cancel:"
  read -rp "👉 Choice: " sel
  [[ -z "$sel" ]] && return

  declare -A MARK
  IFS=',' read -r -a parts <<<"$sel"
  local p
  for p in "${parts[@]}"; do
    if [[ "$p" =~ ^[0-9]+-[0-9]+$ ]]; then
      local a=${p%-*} b=${p#*-}
      ((a<1)) && a=1; ((b>idx)) && b=$idx
      local i; for ((i=a;i<=b;i++)); do MARK[$((i-1))]=1; done
    elif [[ "$p" =~ ^[0-9]+$ ]]; then
      ((p>=1 && p<=idx)) && MARK[$((p-1))]=1
    fi
  done

  local total=0
  local -a victims=()
  local i
  printf "%s\n" "You are about to delete:"
  for i in "${!MARK[@]}"; do
    victims+=("$i")
    (( total += ${IDX_BYTES[$i]} ))
    printf "  - %s [%s]\n" "${IDX_LABEL[$i]}" "$(human ${IDX_BYTES[$i]})"
  done

  ((${#victims[@]}==0)) && { printf "No valid entries.\n"; read -rp "Press Enter... " _; return; }

  local total_h; total_h=$(human "$total")
  read -rp "❗ Confirm deletion of ${#victims[@]} prefix(es) (~$total_h freed)? [y/N]: " ok
  [[ "$ok" != "y" ]] && { printf "Cancelled.\n"; read -rp "Press Enter... " _; return; }

  local fail=0
  for i in "${victims[@]}"; do
    local p="${IDX_PATH[$i]}"
    [[ -n "$p" && -d "$p" && "$p" != "/" ]] && rm -rf --one-file-system "$p" || fail=1
  done

  ((fail==0)) && printf "Done. Freed ~%s\n" "$total_h" || printf "Some dirs not removed.\n"
  read -rp "Press Enter to go back... " _
}

##################################### NVIDIA RELATED

nvidia_menu() {
  while true; do
    clear
    echo ""
    echo -e "🌸${RED} Nvidia Personal Configuration 🌸 ${RESET} "
    echo ""
    echo "1. 🌹 Power Limit & Fan Curve"
    echo "2. 🐧 Install Zen Kernel (NVIDIA-DKMS)"
    echo "3. 👈 Back to main menu"
    echo ""
    read -p "Choose an option: " choice

    case "$choice" in
    1) nvidia_fan_setup ;;
    2) install_zen_kernel_nvidia ;;
    3) break ;;
    *) echo "❌ Invalid option." ;;
    esac
  done
}

####################################
nvidia_fan_setup() {
  clear
  echo -e "\n🌸 ${RED} NVIDIA GPU Fan Curve & Power Limit Setup 🌸 ${RESET}\n"
  echo ""
  echo "This setup will allow you to apply a custom fan curve and undervolt your NVIDIA GPU."
  echo ""
  echo -e "⚠️ These settings are tuned for a 2-fan GPU (e.g., 3060 Ti). Adjust only if you know what you're doing. Mind the Power Limit is set to 130w. Change it in ${CYAN}reakjra.conf.sh${RESET} if you need to."
  echo

  # Step 1: Install Required Packages
  echo "🌸 Step 1: Install required NVIDIA packages (nvidia, nvidia-utils, etc.)"
  read -rp "Install packages? [Y/n]: " install_packages
  if [[ "$install_packages" =~ ^[Yy]$ || -z "$install_packages" ]]; then
    sudo pacman -S --needed nvidia nvidia-utils lib32-nvidia-utils nvidia-smi nvidia-settings xorg-xhost
  else
    echo ""
    echo "⚠️ Skipping package installation may cause the setup to fail."
  fi

  # Step 2: Configure sudoers for passwordless access
  echo -e "\n🌸 step 2: Configure passwordless sudo for GPU tools (nvidia-smi, nvidia-settings)"
  read -rp "Configure sudoers? [Y/n]: " configure_sudoers
  if [[ "$configure_sudoers" =~ ^[Yy]$ || -z "$configure_sudoers" ]]; then
    sudo tee /etc/sudoers.d/gpucontrol >/dev/null <<EOF
$USER ALL=(ALL) NOPASSWD: /usr/bin/nvidia-settings
$USER ALL=(ALL) NOPASSWD: /usr/bin/nvidia-smi
$USER ALL=(ALL) NOPASSWD: /usr/bin/env
EOF
  else
    echo ""
    echo "⚠️ Skipping sudoers setup may prevent scripts from working correctly."
  fi

  # Step 3: Enable CoolBits for manual fan control
  echo -e "\n🌸 Step 3: Enable CoolBits (required for fan control)"
  read -rp "Enable CoolBits? [Y/n]: " enable_coolbits
  if [[ "$enable_coolbits" =~ ^[Yy]$ || -z "$enable_coolbits" ]]; then
    sudo mkdir -p /etc/X11/xorg.conf.d/
    sudo tee /etc/X11/xorg.conf.d/20-nvidia.conf >/dev/null <<EOF
Section "Device"
    Identifier "Nvidia Card"
    Driver "nvidia"
    Option "Coolbits" "31"
EndSection
EOF
    echo "✅ CoolBits set to 31. You do NOT need to reboot."
  else
    echo ""
    echo "⚠️ Skipping CoolBits setup will break fan control."
  fi

  # Step 4: Create undervolt script (power limit)
  echo -e "\n🌸 Step 4: Create undervolt script (gpu-limit.sh)"
  read -rp "Create gpu-limit.sh? [Y/n]: " create_gpu_limit
  if [[ "$create_gpu_limit" =~ ^[Yy]$ || -z "$create_gpu_limit" ]]; then
    cat >~/gpu-limit.sh <<EOF
#!/bin/bash
sudo nvidia-smi -pl 150
EOF
    sudo chmod +x ~/gpu-limit.sh
    echo "✅ gpu-limit.sh created and made executable."
  fi

  # Step 5: Create fan curve control script
  echo -e "\n🌸 Step 5: Create fan curve script (nvidia_fan_control.sh)"
  read -rp "Create fan control script? [Y/n]: " create_fan_script
  if [[ "$create_fan_script" =~ ^[Yy]$ || -z "$create_fan_script" ]]; then
    cat >~/nvidia_fan_control.sh <<'EOF'
#!/bin/bash

LOG_FILE="/tmp/nvidia_fan_control.log"
> "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

FAN_CURVE=(
    "40:30"
    "50:40"
    "60:50"
    "70:65"
    "75:70"
    "80:75"
    "90:100"
)
INTERVAL_SECONDS=5

run_nvidia_settings() {
    export DISPLAY="${DISPLAY:-:0}"
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    sudo env DISPLAY="$DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" nvidia-settings "$@"
}

get_gpu_temp() {
    nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader
}

set_fan_speed() {
    local speed_percent=$1
    local fans_to_control=("0" "1")
    for fan_id in "${fans_to_control[@]}"; do
        run_nvidia_settings -a "[fan:${fan_id}]/GPUTargetFanSpeed=${speed_percent}"
    done
}

echo "Enabling manual fan control..."
run_nvidia_settings -a "[gpu:0]/GPUFanControlState=1"

while true; do
    GPU_TEMP=$(get_gpu_temp)
    TARGET_SPEED=30
    for entry in "${FAN_CURVE[@]}"; do
        temp_threshold=$(echo "$entry" | cut -d':' -f1)
        speed_value=$(echo "$entry" | cut -d':' -f2)
        if (( GPU_TEMP >= temp_threshold )); then
            TARGET_SPEED=$speed_value
        fi
    done
    echo "GPU Temp: ${GPU_TEMP}°C, Fan Speed: ${TARGET_SPEED}%"
    set_fan_speed "$TARGET_SPEED"
    sleep "$INTERVAL_SECONDS"
done
EOF
    sudo chmod +x ~/nvidia_fan_control.sh
    echo "✅ nvidia_fan_control.sh created and made executable."
    echo ""
  fi

  # Step 6: Add xhost line for root display access
  echo -e "\n🌸 Step 6: Allow root user access to X11 (needed for nvidia-settings)"
  read -rp "Run xhost setup now? [Y/n]: " xhost_confirm
  if [[ "$xhost_confirm" =~ ^[Yy]$ || -z "$xhost_confirm" ]]; then
    xhost +si:localuser:root
    echo "✅ Root access to display granted (xhost)."
  else
    echo ""
    echo "⚠️ Without xhost, fan control script will likely fail under sudo."
    echo ""
  fi

  echo -e "\n✅ Setup complete!"
  echo ""
  echo -e "\n🌸 Step 7: Autostart configuration for Hyprland"
  read -rp "Do you want to automatically start the fan and power limit scripts on boot? [Y/n]: " autostart_confirm
  if [[ "$autostart_confirm" =~ ^[Yy]$ || -z "$autostart_confirm" ]]; then
    AUTOSTART_LINE1='exec = ~/gpu-limit.sh'
    AUTOSTART_LINE2='exec-once = bash -c "sleep 1 && xhost +si:localuser:root && sleep 2 && ~/nvidia_fan_control.sh &"'

    if [[ -f "$HOME/.config/hypr/userprefs.conf" ]]; then
      echo -e "\n✅ Detected HyDE userprefs.conf"
      echo -e "\n# NVIDIA GPU Scripts" >>"$HOME/.config/hypr/userprefs.conf"
      echo "$AUTOSTART_LINE1" >>"$HOME/.config/hypr/userprefs.conf"
      echo "$AUTOSTART_LINE2" >>"$HOME/.config/hypr/userprefs.conf"
      echo "✅ Added to ~/.config/hypr/userprefs.conf"
    elif [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
      echo -e "\nℹ️ userprefs.conf not found. Falling back to hyprland.conf."
      echo -e "\n# NVIDIA GPU Scripts" >>"$HOME/.config/hypr/hyprland.conf"
      echo "$AUTOSTART_LINE1" >>"$HOME/.config/hypr/hyprland.conf"
      echo "$AUTOSTART_LINE2" >>"$HOME/.config/hypr/hyprland.conf"
      echo "✅ Added to ~/.config/hypr/hyprland.conf"
    else
      echo -e "\n❌ Could not find any Hyprland configuration file."
      echo "Please add the following lines manually to your config:"
      echo "$AUTOSTART_LINE1"
      echo "$AUTOSTART_LINE2"
    fi
  else
    echo ""
    echo "⚠️ Skipping autostart. You'll need to launch the scripts manually."
  fi

  echo ""
  echo ""
  read -rp "🌸 Press Enter to return to the NVIDIA menu..."
}

####################################
install_zen_kernel_nvidia() {
  echo ""
  read -p "🌸 Do you want to install the Linux-Zen Kernel? (y/n): " confirm
  [[ "$confirm" != "y" ]] && return

  echo ""
  echo "🐧 Installing Linux-Zen Kernel and headers..."
  sudo pacman -S --noconfirm linux-zen linux-zen-headers

  echo ""
  read -p "🌹 Do you want to reinstall nvidia-dkms for the Zen kernel? (y/n): " reinstall_dkms
  if [[ "$reinstall_dkms" == "y" ]]; then
    echo "🔧 Reinstalling NVIDIA DKMS..."
    sudo pacman -S --noconfirm nvidia-dkms
  else
    echo "⏩ Skipping NVIDIA DKMS reinstall..."
  fi

  echo ""
  read -p "⚙️  Do you want to regenerate your GRUB config? (y/n): " update_grub
  if [[ "$update_grub" == "y" ]]; then
    echo "📝 Updating GRUB config..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
  else
    echo "🔕 Skipping GRUB config update..."
  fi

  echo -e "${GREEN}🌸 Zen Kernel installation complete! You can select it from GRUB on next boot.${RESET}"
  pause
}



##################################### 🔁 MAIN MENU LOOP
while true; do
  main_menu
done


