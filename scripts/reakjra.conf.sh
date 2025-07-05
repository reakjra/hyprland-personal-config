#!/bin/bash

# Pretty colors
GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
PINK="\e[38m"
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
    echo "8. 🎮 Install Gamemode and apply"
    echo "9. 🥚 Nvidia Configuration"
    echo "10. 🌸 HyDE/Hypr Personal Settings"
    echo "11. ❌ Exit"
    echo ""

    read -p "👉 Select an option (1-10): " choice
    case $choice in
        1) mount_drives_section ;;
        2) fix_dualboot_time ;;
        3) install_discord_with_fix ;;
        4) install_spotify_spicetify ;;
        5) install_gaming_section ;;
        6) install_gaming_monitoring_tools ;;
        7) install_lib32_multimedia ;;
        8) install_gamemode_section ;; 
        9) nvidia_menu ;;
        10) wm_settings_menu ;;
        11) echo "👋 Goodbye!"; exit 0 ;;
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
    read -p "📊 Do you want to install MangoHud and vkBasalt with custom configs? (y/n): " confirm
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

    # Ask for MangoHud config type
    mkdir -p ~/.config/MangoHud
    mango_conf=~/.config/MangoHud/MangoHud.conf

    if [[ -f "$mango_conf" ]]; then
        echo "⚠️  MangoHud config already exists, skipping creation."
    else
        echo ""
        echo "🛠️  Choose MangoHud config type:"
        echo "1) Minimal"
        echo "2) Full"
        read -p "Enter your choice (1/2): " config_choice

        if [[ "$config_choice" == "1" ]]; then
            echo "📝 Creating Minimal MangoHud config..."
            cat << EOF > "$mango_conf"
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
text=\$fps | \$gpu_temp

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
        else
            echo "📝 Creating Full MangoHud config..."
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
        fi
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

# 🌸 LIB32 MULTIMEDIA
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


# 🌸 INSTALL GAMEMODE
install_gamemode_section() {
    echo ""
    read -p "🌸 Do you want to install and configure Gamemode? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    # Step 1: Install gamemode
    if command -v gamemoded &> /dev/null; then
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





# 🌸 WM SETTINGS MENU
wm_settings_menu() {
    while true; do
        clear
        echo ""
        echo -e "🌸${RED} WM Personal Settings (HyDE only) 🌸 ${RESET} "
        echo ""
        echo "1. 🍼 Update userprefs.conf (it will override the current one)"
        echo "2. 🍼 Update windowrules.conf (it will override the current one)"
        echo "3. 🍼 Apply wallbash theme to Visual Studio Code"
        echo "4. 👈 Back to main menu"
        echo ""
        read -p "Choose an option: " choice

        case "$choice" in
            1) update_userprefs ;;
            2) update_windowsrules ;;
            3) apply_wallbash_code_theme ;;
            4) break ;;
            *) echo "❌ Invalid option." ;;
        esac
    done
}

# 🌸 WM SETTINGS: USERPREFS
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
    GITHUB_URL="https://raw.githubusercontent.com/reakjra/hyprland-personal-config/refs/heads/main/scripts/HyDE/userprefs.conf"
    echo "⬇️ Downloading new config from GitHub..."

    if curl -fsSL "$GITHUB_URL" -o "$TARGET"; then
        echo "✅ userprefs.conf successfully updated!"
    else
        echo "❌ Failed to download the file. Reverting to your previous config."
        cp "$BACKUP" "$TARGET"
        echo "🔁 Reverted to: $BACKUP"
    fi
}

# 🌸  UPDATE WINDOWRULES.CONF
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
    GITHUB_URL="https://raw.githubusercontent.com/reakjra/hyprland-personal-config/refs/heads/main/scripts/HyDE/windowrules.conf"
    echo "⬇️ Downloading new config from GitHub..."

    if curl -fsSL "$GITHUB_URL" -o "$TARGET"; then
        echo "✅ windowrules.conf successfully updated!"
    else
        echo "❌ Failed to download the file. Reverting to your previous config."
        cp "$BACKUP" "$TARGET"
        echo "🔁 Reverted to: $BACKUP"
    fi
}

# 🌸 APPLY WALLBASH THEME TO VISUAL STUDIO CODE
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






# NVIDIA RELATED 

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
        cat > ~/gpu-limit.sh <<EOF
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
        cat > ~/nvidia_fan_control.sh <<'EOF'
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
            echo -e "\n# NVIDIA GPU Scripts" >> "$HOME/.config/hypr/userprefs.conf"
            echo "$AUTOSTART_LINE1" >> "$HOME/.config/hypr/userprefs.conf"
            echo "$AUTOSTART_LINE2" >> "$HOME/.config/hypr/userprefs.conf"
            echo "✅ Added to ~/.config/hypr/userprefs.conf"
        elif [[ -f "$HOME/.config/hypr/hyprland.conf" ]]; then
            echo -e "\nℹ️ userprefs.conf not found. Falling back to hyprland.conf."
            echo -e "\n# NVIDIA GPU Scripts" >> "$HOME/.config/hypr/hyprland.conf"
            echo "$AUTOSTART_LINE1" >> "$HOME/.config/hypr/hyprland.conf"
            echo "$AUTOSTART_LINE2" >> "$HOME/.config/hypr/hyprland.conf"
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




 
# 🔁 MAIN MENU LOOP
while true; do
    main_menu
done
