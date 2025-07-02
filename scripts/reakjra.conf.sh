#!/bin/bash

# Pretty colors
GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

pause() {
    echo ""
    read -p "🌸 Press enter to return to the menu..."
    echo ""
}

# ✨ MAIN MENU
main_menu() {
    clear
    echo -e "${RED}🌸 Welcome to Reakjra's personal EndeavourOS configuration script! 🌸${RESET}"
    echo ""
    echo "1. 📁 Mount partitions (NTFS)"
    echo "2. 🕒 Fix dual boot time issue" 
    echo "3. 🗣  Install Discord with fix"
    echo "4. 🎵 Spotify & Spicetify Patch"
    echo "5. 🎮 Install Steam, Bottles and GE-Proton"
    echo "6. 🎮 Install MangoHud and vkBasalt with configs"
    echo "7. 🎮 Install lib32* Multimedia"
    echo "8. 🌸 WM Personal Settings"
    echo "9. ❌ Exit"
    echo ""

    read -p "👉 Select an option (1-9): " choice
    case $choice in
        1) mount_drives_section ;;
        2) fix_dualboot_time ;;
        3) install_discord_with_fix ;;
        4) install_spotify_spicetify ;;
        5) install_gaming_section ;;
        6) install_gaming_monitoring_tools ;;
        7) install_lib32_multimedia ;;
        8) wm_settings_menu ;;
        9) echo "👋 Goodbye!"; exit 0 ;;
        *) echo "❌ Invalid choice."; pause ;;
    esac
}

# 🌸 MOUNT NTFS PARTITIONS
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
    read -p "👉 Enter the partition numbers to mount (e.g. 1,3,4): " selections

    # Make sure ntfs-3g is installed
    if ! command -v ntfs-3g &> /dev/null; then
        echo "📦 'ntfs-3g' not found. Installing it..."
        sudo pacman -S --noconfirm ntfs-3g
    fi

    IFS=',' read -ra SELECTED <<< "$selections"
    for sel in "${SELECTED[@]}"; do
        idx=$((sel - 1))
        [[ -z "${INDEXED_PARTS[$idx]}" ]] && echo "⚠️  Partition $sel is invalid, skipping." && continue

        IFS="|" read -r name uuid fstype mountpoint <<< "${INDEXED_PARTS[$idx]}"
        dev="/dev/$name"
        mount_dir=~/"$name"

        [[ -n "$mountpoint" ]] && echo "⚠️  $name is already mounted at $mountpoint. Skipping." && continue

        echo "🔗 Mounting $name to $mount_dir..."
        mkdir -p "$mount_dir"

        [[ "$fstype" == "ntfs" ]] && sudo mount -t ntfs-3g "$dev" "$mount_dir" -o uid=$(id -u),gid=$(id -g) || sudo mount "$dev" "$mount_dir"

        read -p "📝 Add $name to /etc/fstab for auto-mount on boot? (y/n): " add_fstab
        if [[ "$add_fstab" == "y" ]]; then
            username=$(whoami)
            echo "UUID=${uuid} /home/${username}/${name} ntfs-3g defaults,uid=1000,gid=1000,rw,user,exec,umask=000 0 0" | sudo tee -a /etc/fstab > /dev/null
            echo "✅ Added to /etc/fstab"
        fi
    done

    echo "🎉 Partition mounting section completed!"
    pause
}

# 🌸 INSTALL STEAM, BOTTLES AND GE-PROTON
install_gaming_section() {
    echo ""
    read -p "🎮 Do you want to install Steam, Bottles and GE-Proton? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    echo "🔍 Checking for installed components..."

    # Check Steam
    if command -v steam &> /dev/null; then
        echo "✅ Steam is already installed."
    else
        echo "📦 Installing Steam..."
        sudo pacman -S --noconfirm steam
    fi

    # Check Bottles
    if command -v bottles &> /dev/null; then
        echo "✅ Bottles is already installed."
    else
        echo "📦 Installing Bottles..."
        sudo pacman -S --noconfirm bottles
    fi

    echo "🌐 Fetching latest GE-Proton release..."

    mkdir -p ~/.local/share/Steam/compatibilitytools.d
    mkdir -p ~/.local/share/bottles/runners

    latest_url=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest \
                 | grep "browser_download_url" | grep ".tar.gz" | cut -d '"' -f 4 | head -n 1)

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

# 🌸  FIX DUAL BOOT TIME
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
    read -p "📊 Do you want to install MangoHud and vkBasalt with default configs? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    # Install MangoHud
    if command -v mangohud &> /dev/null; then
        echo "✅ MangoHud is already installed."
    else
        echo "📦 Installing MangoHud..."
        sudo pacman -S --noconfirm mangohud
    fi

    # Install vkBasalt
    if command -v vkBasalt &> /dev/null; then
        echo "✅ vkBasalt is already installed."
    else
        echo "📦 Installing vkBasalt..."
        sudo pacman -S --noconfirm vkbasalt
    fi

    # MangoHud config
    mkdir -p ~/.config/MangoHud
    mango_conf=~/.config/MangoHud/MangoHud.conf
    if [[ -f "$mango_conf" ]]; then
        echo "⚠️  MangoHud config already exists, skipping creation."
    else
        echo "📝 Creating MangoHud config..."
        cat << EOF > "$mango_conf"
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
\${cpu_stats} CPU: \${cpu_temp}C (\${cpu_power}W)
\${core_freq}
\${gpu_stats} GPU: \${gpu_temp}C (\${gpu_power}W) Fan: \${gpu_fan}
\${gpu_core_clock} / \${gpu_mem_clock}
FPS: \${fps}
\${frame_timing}
RAM: \${ram} / VRAM: \${vram}
EOF
        echo "✅ MangoHud config created."
    fi

    # vkBasalt config
    mkdir -p ~/.config/vkBasalt
    vk_conf=~/.config/vkBasalt/vkBasalt.conf
    if [[ -f "$vk_conf" ]]; then
        echo "⚠️  vkBasalt config already exists, skipping creation."
    else
        echo "📝 Creating vkBasalt config..."
        cat << EOF > "$vk_conf"
# vkBasalt configuration file

effects = cas

# Effect Settings
cas = 0.1

# Toggle key
toggleKey = 59
EOF
        echo "✅ vkBasalt config created."
    fi

    echo -e "${GREEN}🎉 Monitoring tools installed and configured!${RESET}"
    pause
}

# 🌸 Install Discord with fix
install_discord_with_fix() {
  echo ""
    read -p "💬 Do you want to install Discord? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    if command -v discord &> /dev/null; then
        echo "✅ Discord is already installed."
    else
        echo "📦 Installing Discord..."
        sudo pacman -S --noconfirm discord
    fi

    echo ""

    if ! command -v jq &> /dev/null; then
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
            jq '. + {"SKIP_HOST_UPDATE": true}' "$settings_file" > "$tmp_file" && mv "$tmp_file" "$settings_file"
        fi
    else
        echo "📝 Creating settings.json..."
        cat << EOF > "$settings_file"
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


# 🌸 SPOTIFY & SPICETIFY
install_spotify_spicetify() {
    echo ""
    echo "🎵 This will install Spotify and patch it using Spicetify CLI + Marketplace."
    read -p "Continue? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    echo "📦 Installing Spotify and Spicetify CLI..."
    sudo pacman -S spotify --noconfirm
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


# 🌸 WM SETTINGS MENU
wm_settings_menu() {
    while true; do
        clear
        echo ""
        echo -e "🌸${RED} WM Personal Settings (HyDE only) 🌸 ${RESET} "
        echo ""
        echo "1. 🍼 Update userprefs.conf (startup applications and keyboard layout)"
        echo ""
        echo "2. 🔙 Back to main menu"
        echo ""
        read -p "Choose an option: " choice

        case "$choice" in
            1) update_userprefs ;;
            2) break ;;
            *) echo "❌ Invalid option." ;;
        esac
    done
}


# 🌸 LIB32 MULTIMEDIA
install_lib32_multimedia() {
    echo ""
    echo "🎮 This will install essential lib32 multimedia libraries for better audio/video support in some games."
    echo "⚠️  This is especially useful for games like Resident Evil 2 Remake and Days Gone Remastered."
    echo "⏳ The installation can take a while (~30 minutes depending on your system and internet speed)."
    read -p "Do you want to continue? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    yay -S lib32-gstreamer lib32-gst-plugins-base lib32-gst-plugins-good lib32-gst-plugins-bad lib32-gst-plugins-ugly \
           lib32-libva lib32-libx264 lib32-libvpx lib32-libmpeg2 lib32-openal \
           lib32-libpulse lib32-ffmpeg lib32-vulkan-icd-loader --noconfirm

    echo "✅ All lib32 multimedia libraries have been installed."
    pause
} 


 
# 🌸 WM SETTINGS: USERPREFS
update_userprefs() {
    echo ""
    echo "⚠️  These settings are personal and intended ONLY for HyDE (Hyprland dotfiles)."
    echo "📁 Target file: ~/.config/hypr/userprefs.conf"
    echo ""
    read -p "Do you want to continue? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    prefs_file="$HOME/.config/hypr/userprefs.conf"

    # Check se il file esiste
    if [[ ! -f "$prefs_file" ]]; then
        echo "❌ userprefs.conf not found. Are you using HyDE dotfiles?"
        pause
        return
    fi

    # Blocchi da aggiungere
    block_to_add=$(cat << 'EOF'
# -----------------------------------------------------
# AUTORUN APPLICATIONS AND ASSIGN TO WORKSPACES AT BOOT
# -----------------------------------------------------

# Workspace 1: Steam Big Picture Mode

exec-once = [workspace 1 silent] steam -bigpicture
windowrule = fullscreen, class:^Steam$ # Ensure Steam Big Picture is fullscreen
windowrulev2 = workspace 1, class:^(steam_app_.*)$

windowrulev2 = workspace 2 silent, class:^(discord)$
exec-once = sh -c 'sleep 5 && discord'

exec-once = [workspace 3 silent] firefox
EOF
)

    # Check se una parte del blocco è già presente
    if grep -q "exec-once = \[workspace 1 silent\] steam -bigpicture" "$prefs_file"; then
        echo "✅ These autostart entries are already present."
        echo "📝 Adding a small marker comment to indicate check success."

        echo -e "\n# ദ്ദി(˵ •̀ ᴗ - ˵ ) ✧" >> "$prefs_file"
    else
        echo "✏️ Appending autostart workspace assignments to userprefs.conf..."
        echo -e "\n$block_to_add\n# ദ്ദി(˵ •̀ ᴗ - ˵ ) ✧" >> "$prefs_file"
        echo "✅ Added new entries."
    fi

    pause
}

 
# 🔁 MAIN MENU LOOP
while true; do
    main_menu
done
