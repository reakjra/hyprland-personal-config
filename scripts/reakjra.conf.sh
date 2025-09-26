#!/bin/bash

##################################### 🌸 USER CONFIGURATION SECTION
# Customize these values according to your preferences and system
# Feel free to modify any values to match your setup! 💖

# NVIDIA Configuration 🥚
NVIDIA_POWER_LIMIT=150              # GPU power limit in watts (adjust for your GPU)
NVIDIA_FAN_CURVE=(                  # Temperature:Speed pairs for custom fan curve (you'll need to change it through the nvidia fan curve script once done)
    "40:30"  "50:40"  "60:50"  "70:65"  "75:70"  "80:75"  "90:100"
)
NVIDIA_FAN_IDS=("0" "1")           # Fan IDs to control (0 and 1 for dual-fan GPUs)
NVIDIA_FAN_INTERVAL=5              # Fan control check interval in seconds

# AMD Configuration 🔴
AMD_POWER_PROFILE=1                # Power profile (0=3D_FULL_SCREEN, 1=BALANCED, 2=POWER_SAVING)

# Hyprland Configuration Files 🌸
# Specify which files to use for different types of configurations
# You can use the same file for everything or split them as you prefer!
HYPR_KEYBINDS="$HOME/.config/hypr/custom/keybinds.conf"             # For keybinds
HYPR_WINDOWRULES="$HOME/.config/hypr/custom/rules.conf"             # For window rules
HYPR_GENERAL="$HOME/.config/hypr/custom/general.conf"               # For general settings
HYPR_ENV="$HOME/.config/hypr/custom/env.conf"                       # For environment variables
HYPR_EXECS="$HOME/.config/hypr/custom/execs.conf"                   # For exec/exec-once commands

# Package Management 📦
AUR_HELPER="yay"                   # AUR helper to use (yay, paru, etc.)

# Script Behavior ⚙️
LOG_DIR="$HOME/reakjra-CC-logs"    # Directory for storing operation logs
AUTO_BACKUP=false                  # Automatically backup config files before modifying | reccomended set to false to avoid useless backups
DEFAULT_CONFIRM=true               # Default response for confirmations (true=yes, false=no)

# Directories 📁
CONFIG_BACKUP_DIR="$HOME/.config_backups" # Directory for config backups

# Gaming Configuration 🎮
GAMEMODE_GROUPS=("gamemode")       # Groups to add user to for gamemode access

# GitHub Configuration for WM settings (This is for Reakjra's Hyprland config, do not touch) 🌐
GITHUB_USERNAME="reakjra"          # GitHub username for configs
GITHUB_REPO="hyprland-personal-config" # Repository name
GITHUB_BRANCH="main"               # Branch to use

##############################################################################



#TODO: default packages installer: Gwenview, mpv, Ark, Kate | Flatpak, Warehouse // useful for more minimalist Hyprland rices

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

##################################### 🌸 UTILITY FUNCTIONS
# Consistent UI/UX functions used throughout the script

# Message functions with consistent styling
msg_info() {
    echo -e "ℹ️  $1"
}

msg_success() {
    echo -e "${GREEN}✅ $1${RESET}"
}

msg_warning() {
    echo -e "${YELLOW}⚠️  $1${RESET}"
}

msg_error() {
    echo -e "${RED}❌ $1${RESET}"
}

msg_step() {
    echo -e "\n🌸 $1"
}

msg_section() {
    echo -e "\n🌸 ${RED}$1${RESET}"
}

# Confirmation functions
confirm() {
    local message="$1"
    local default="${2:-$DEFAULT_CONFIRM}"
    local prompt="[Y/n]"

    [[ "$default" == false ]] && prompt="[y/N]"

    while true; do
        read -rp "❓ $message $prompt: " response
        case "${response,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            "") [[ "$default" == true ]] && return 0 || return 1 ;;
            *) msg_warning "Please enter y/n." ;;
        esac
    done
}

confirm_or_exit() {
    if ! confirm "$1" "$2"; then
        msg_info "Operation cancelled."
        pause
        return 1
    fi
}

# Input functions
get_input() {
    local message="$1"
    local default="$2"
    local response

    if [[ -n "$default" ]]; then
        read -rp "👉 $message [$default]: " response
        echo "${response:-$default}"
    else
        read -rp "👉 $message: " response
        echo "$response"
    fi
}

# Package management utilities
check_package() {
    local package="$1"
    if command -v "$package" &>/dev/null || pacman -Q "$package" &>/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

install_package() {
    local package="$1"
    local method="${2:-pacman}"  # pacman, aur, or specific command

    if check_package "$package"; then
        msg_success "$package is already installed."
        return 0
    fi

    msg_step "Installing $package..."
    case "$method" in
        pacman)
            sudo pacman -S --needed --noconfirm "$package"
            ;;
        aur)
            if ! command -v "$AUR_HELPER" &>/dev/null; then
                msg_error "$AUR_HELPER is required for AUR packages. Please install it first."
                return 1
            fi
            "$AUR_HELPER" -S --needed --noconfirm "$package"
            ;;
        *)
            eval "$method"
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        msg_success "$package installed successfully."
        return 0
    else
        msg_error "Failed to install $package."
        return 1
    fi
}

install_packages() {
    local method="$1"
    shift
    local packages=("$@")
    local failed=()

    for package in "${packages[@]}"; do
        if ! install_package "$package" "$method"; then
            failed+=("$package")
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        msg_error "Failed to install: ${failed[*]}"
        return 1
    fi
    return 0
}

# File management utilities
backup_file() {
    local file="$1"
    local backup_dir="${2:-$CONFIG_BACKUP_DIR}"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    mkdir -p "$backup_dir"
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local backup_name="${file##*/}.${BACKUP_SUFFIX}-${timestamp}"
    local backup_path="$backup_dir/$backup_name"

    cp "$file" "$backup_path"
    msg_success "Backup created: $backup_path"
}

# Hyprland configuration utilities
add_to_hypr_config() {
    local config_type="$1"  # keybinds, windowrules, general, env, execs
    local content="$2"
    local comment="$3"

    local target_file
    case "$config_type" in
        keybinds) target_file="$HYPR_KEYBINDS" ;;
        windowrules) target_file="$HYPR_WINDOWRULES" ;;
        general) target_file="$HYPR_GENERAL" ;;
        env) target_file="$HYPR_ENV" ;;
        execs) target_file="$HYPR_EXECS" ;;
        *)
            msg_error "Invalid config type: $config_type"
            return 1
            ;;
    esac

    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$target_file")"

    # Create file if it doesn't exist
    [[ ! -f "$target_file" ]] && touch "$target_file"

    # Backup if auto backup is enabled
    [[ "$AUTO_BACKUP" == true ]] && backup_file "$target_file"

    # Check if content already exists
    if grep -Fxq "$content" "$target_file"; then
        msg_success "Configuration already present in $target_file"
        return 0
    fi

    # Add content with comment
    {
        echo ""
        [[ -n "$comment" ]] && echo "# $comment"
        echo "$content"
    } >> "$target_file"

    msg_success "Added to $target_file"
}

# Service management utilities
manage_service() {
    local action="$1"  # enable, disable, start, stop, enable-now
    local service="$2"
    local user_service="${3:-false}"

    local systemctl_cmd="sudo systemctl"
    [[ "$user_service" == true ]] && systemctl_cmd="systemctl --user"

    msg_step "${action^}ing $service service..."

    case "$action" in
        enable-now)
            $systemctl_cmd enable --now "$service"
            ;;
        *)
            $systemctl_cmd "$action" "$service"
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        msg_success "$service service ${action}d successfully."
        return 0
    else
        msg_error "Failed to $action $service service."
        return 1
    fi
}

check_service_status() {
    local service="$1"
    local user_service="${2:-false}"

    local systemctl_cmd="systemctl"
    [[ "$user_service" == true ]] && systemctl_cmd="systemctl --user"

    if $systemctl_cmd is-active --quiet "$service"; then
        msg_success "$service is running."
        return 0
    else
        msg_warning "$service is not running."
        return 1
    fi
}

# GitHub utilities
github_download() {
    local path="$1"
    local output="$2"
    local url="https://raw.githubusercontent.com/${GITHUB_USERNAME}/${GITHUB_REPO}/${GITHUB_BRANCH}/${path}"

    msg_step "Downloading from GitHub..."
    if curl -fsSL "$url" -o "$output"; then
        msg_success "Downloaded successfully."
        return 0
    else
        msg_error "Download failed."
        return 1
    fi
}

# Logging utilities
create_log() {
    local operation="$1"
    local timestamp=$(date +%Y-%m-%dT%H-%M-%S)
    local logfile="$LOG_DIR/${operation}_$timestamp.txt"

    mkdir -p "$LOG_DIR"
    echo "$logfile"
}

log_operation() {
    local operation="$1"
    local content="$2"
    local logfile=$(create_log "$operation")

    echo "$content" > "$logfile"
    msg_success "Operation logged: $logfile"
}

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
  echo "11. 🔴 AMD Configuration"
  echo "12. 🧹 Cleaner and Maintanance"
  echo "13. 🌸 Reakjra's Hypr"
  echo "14. ❌ Exit"
  echo ""

  read -p "👉 Select an option (1-14): " choice
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
  11) amd_menu ;;
  12) cleaner_menu ;;
  13) reakjra_hypr_menu ;;
  14)
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




##################################### 🌸 INSTALL STEAM, BOTTLES, LUTRIS AND GE-PROTON
install_gaming_section() {
  echo ""

  while true; do
    read -p "🌸 Install Steam? (y/n): " a
    case "$a" in
      [yY])
        if command -v steam &>/dev/null; then
          echo -e "${GREEN}🌸 Steam is already installed.${RESET}"
        else
          echo "🌸 Installing Steam..."
          sudo pacman -S --noconfirm steam
        fi
        break ;;
      [nN]) echo "🌸 Skipping Steam."; break ;;
      *) echo -e "${YELLOW}🌸 Please enter y/n.${RESET}" ;;
    esac
  done

  echo ""

  while true; do
    read -p "🌸 Install Bottles (AUR)? (y/n): " b
    case "$b" in
      [yY])
        if command -v bottles &>/dev/null; then
          echo -e "${GREEN}🌸 Bottles is already installed.${RESET}"
        else
          echo "🌸 Installing Bottles (yay)..."
          yay -S --noconfirm bottles
        fi
        break ;;
      [nN]) echo "🌸 Skipping Bottles."; break ;;
      *) echo -e "${YELLOW}🌸 Please enter y/n.${RESET}" ;;
    esac
  done

  echo ""

  while true; do
    read -p "🌸 Install Lutris? (y/n): " l
    case "$l" in
      [yY])
        if command -v lutris &>/dev/null; then
          echo -e "${GREEN}🌸 Lutris is already installed.${RESET}"
        else
          echo "🌸 Installing Lutris..."
          sudo pacman -S --noconfirm lutris
        fi
        break ;;
      [nN]) echo "🌸 Skipping Lutris."; break ;;
      *) echo -e "${YELLOW}🌸 Please enter y/n.${RESET}" ;;
    esac
  done

  echo ""

  while true; do
    read -p "🌸 Download GE-Proton? (y/n): " g
    case "$g" in
      [yY])
        for dep in curl jq wget tar; do
          if ! command -v "$dep" &>/dev/null; then
            echo "🌸 Installing dependency: $dep"
            sudo pacman -S --noconfirm "$dep"
          fi
        done

        mkdir -p "$HOME/.local/share/Steam/compatibilitytools.d"
        mkdir -p "$HOME/.local/share/bottles/runners"

        local roll
        roll=$(ge_pick_roll_menu) || { echo -e "${RED}🌸 Canceled.${RESET}"; return; }

        echo ""

        local name url
        read name url < <(ge_pick_version_in_roll "$roll") || { echo -e "${RED}🌸 No version selected.${RESET}"; return; }

        echo ""
        echo "🌸 Downloading $name ..."
        local tmp_tar="/tmp/${name}.tar.gz"
        wget -O "$tmp_tar" "$url" || { echo -e "${RED}🌸 Download failed.${RESET}"; return; }

        echo "🌸 Extracting $name ..."
        local topdir
        topdir=$(tar -tzf "$tmp_tar" | head -1 | cut -d/ -f1)
        rm -rf "/tmp/$topdir"
        tar -xzf "$tmp_tar" -C /tmp >/dev/null

        echo ""
        echo "🌸 Where to install $name?"
        echo "1) Steam"
        echo "2) Bottles"
        echo "3) Both"
        read -p "Choose (1/2/3): " dest
        case "$dest" in
          1) cp -r "/tmp/$topdir" "$HOME/.local/share/Steam/compatibilitytools.d/$name"
             echo -e "${GREEN}🌸 Installed to Steam.${RESET}" ;;
          2) cp -r "/tmp/$topdir" "$HOME/.local/share/bottles/runners/$name"
             echo -e "${GREEN}🌸 Installed to Bottles.${RESET}" ;;
          3) cp -r "/tmp/$topdir" "$HOME/.local/share/Steam/compatibilitytools.d/$name"
             cp -r "/tmp/$topdir" "$HOME/.local/share/bottles/runners/$name"
             echo -e "${GREEN}🌸 Installed to both.${RESET}" ;;
          *) cp -r "/tmp/$topdir" "$HOME/.local/share/Steam/compatibilitytools.d/$name"
             cp -r "/tmp/$topdir" "$HOME/.local/share/bottles/runners/$name"
             echo -e "${YELLOW}🌸 Invalid choice; installed to both.${RESET}" ;;
        esac

        echo -e "${GREEN}🌸 GE-Proton ($name) installed.${RESET}"
        return
        ;;
      [nN]) echo "🌸 Skipping GE-Proton."; return ;;
      *) echo -e "${YELLOW}🌸 Please enter y/n.${RESET}" ;;
    esac
  done
}

_print_3col_menu() {
  mapfile -t ITEMS
  local total=${#ITEMS[@]}
  (( total == 0 )) && return 1
  local start_index="${1:-1}"
  local col_size=10
  local col_count=3
  local rows=$(( (total + col_count - 1) / col_count ))
  local r c idx
  for ((r=0;r<rows;r++)); do
    local line=""
    for ((c=0;c<col_count;c++)); do
      idx=$(( r + c*rows ))
      if (( idx < total )); then
        local disp=$(( start_index + idx ))
        printf -v cell "%2d) %s" "$disp" "${ITEMS[$idx]}"
        printf -v cell "%-38s" "$cell"
        line+="$cell"
      fi
    done
    [[ -n "$line" ]] && echo "$line" >&2
  done
}

_ge_fetch_assets_json() {
  local owner="GloriousEggroll"
  local repo="proton-ge-custom"
  local per_page=100
  local page
  for page in 1 2 3; do
    local chunk
    chunk=$(curl -s "https://api.github.com/repos/$owner/$repo/releases?per_page=$per_page&page=$page")
    [[ -z "$chunk" ]] && break
    echo "$chunk" | jq -c '.[] | .assets[]?
      | { name: .name, url: .browser_download_url }'
  done | jq -s '
    map(
      select(.name|test("^GE-Proton[0-9]+-[0-9]+(\\.[0-9]+)?(-[0-9]+)?\\.tar\\.gz$"))
      | .name = (.name|sub("\\.tar\\.gz$"; ""))
      | .maj = (.name | capture("^GE-Proton(?<m>[0-9]+)-").m)
    )'
}

ge_pick_roll_menu() {
  local assets rolls choice
  assets=$(_ge_fetch_assets_json) || return 1
  mapfile -t rolls < <(jq -r '.[].maj' <<<"$assets" | sort -rn | uniq)
  (( ${#rolls[@]} == 0 )) && return 1
  echo "🌸 Choose roll version:" >&2
  local i=1
  for r in "${rolls[@]}"; do
    echo "$i) GE-Proton${r}-x" >&2
    ((i++))
  done
  read -p "Select: " choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#rolls[@]} )); then
    echo -e "${YELLOW}🌸 Invalid selection.${RESET}" >&2
    return 1
  fi
  echo "${rolls[$((choice-1))]}"
}

ge_pick_version_in_roll() {
  local roll="$1"
  [[ -z "$roll" ]] && return 1
  local assets filtered total page_size=30 page=1
  assets=$(_ge_fetch_assets_json) || return 1
  mapfile -t filtered < <(jq -r --arg r "$roll" '.[] | select(.maj==$r) | "\(.name) \(.url)"' <<<"$assets")
  total=${#filtered[@]}
  (( total == 0 )) && return 1
  while true; do
    local start=$(( (page-1)*page_size ))
    local end=$(( start + page_size ))
    (( end > total )) && end=$total
    local slice=("${filtered[@]:$start:$((end-start))}")
    echo "🌸 Choose GE-Proton${roll}-x version:" >&2
    printf "%s\n" "${slice[@]%% *}" | _print_3col_menu $(( start+1 ))
    if (( total > page_size )); then
      echo "" >&2
      echo "Page $page of $(( (total + page_size - 1)/page_size ))" >&2
      echo "n) Next page  p) Previous page" >&2
    fi
    echo "q) Cancel" >&2
    read -p "Select: " sel
    case "$sel" in
      [qQ]) return 1 ;;
      [nN])
        if (( start + page_size < total )); then ((page++)); else echo -e "${YELLOW}🌸 No next page.${RESET}" >&2; fi
        ;;
      [pP])
        if (( page > 1 )); then ((page--)); else echo -e "${YELLOW}🌸 No previous page.${RESET}" >&2; fi
        ;;
      *)
        if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= total )); then
          local idx=$(( sel - 1 ))
          local name="${filtered[$idx]%% *}"
          local url="${filtered[$idx]#* }"
          printf "%s %s\n" "$name" "$url"
          return 0
        else
          echo -e "${YELLOW}🌸 Invalid selection.${RESET}" >&2
        fi
        ;;
    esac
  done
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

  if check_package "vkbasalt"; then
    msg_success "vkBasalt is already installed."
  else
    msg_step "Installing vkBasalt..."
    install_package "vkbasalt" "aur"
  fi

  mkdir -p ~/.config/MangoHud
  mango_dir="$HOME/.config/MangoHud"
  mango_conf="$mango_dir/MangoHud.conf"

  # Check if MangoHud config already exists
  if [[ -f "$mango_conf" ]]; then
    echo ""
    msg_success "MangoHud config already exists."
    if ! confirm "Do you want to overwrite the existing MangoHud configuration?"; then
      msg_info "Keeping existing MangoHud configuration."
    else
      echo ""
      msg_step "Choose MangoHud config type:"
      echo "1) Minimal"
      echo "2) Full"
      echo "3) Dynamic (switch between Minimal/Full)"
      config_choice=$(get_input "Enter your choice" "3")
    fi
  else
    echo ""
    msg_step "Choose MangoHud config type:"
    echo "1) Minimal"
    echo "2) Full"
    echo "3) Dynamic (switch between Minimal/Full)"
    config_choice=$(get_input "Enter your choice" "3")
  fi

  # Only proceed with config creation if we have a choice
  if [[ -n "$config_choice" ]]; then

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

position=top-left
alpha=1.0
background_alpha=0.38
background_color=0A0A0A
round_corners=8
text_outline=1
font_size=22
text_color=FFFFFF
gpu_color=00FF00
cpu_color=00FFFF
frametime_color=FFFF00


gpu_name
fps
fps_metrics=avg,0.01,0.001
frametime
frame_timing

cpu_stats
cpu_temp
cpu_power
cpu_mhz

gpu_list=1
gpu_stats
gpu_temp
gpu_power
gpu_core_clock
gpu_mem_clock
gpu_fan

ram
vram
engine_version
vulkan_driver


reload_cfg=Shift_R+F10

legacy_layout=1

hud_layout=
Drv: ${vulkan_driver}
${gpu_name}
GPU: ${gpu_stats}  ${gpu_temp}C  ${gpu_power}W  Fan:${gpu_fan}
GPU Clk: ${gpu_core_clock}  Mem Clk: ${gpu_mem_clock}
CPU: ${cpu_stats}  ${cpu_temp}C  ${cpu_power}W  ${cpu_mhz}MHz
Mem: RAM ${ram}  VRAM ${vram}
FPS: ${fps}  (avg/1%/0.1%)
${frame_timing}
Frametime: ${frametime}
Eng: ${engine_version}
EOF
    echo "✅ MangoHud config created."
  else
    echo "📝 Creating Dynamic MangoHud profiles..."
    minimal_path="$mango_dir/mangohud-minimal.conf"
    full_path="$mango_dir/mangohud-full.conf"
    cat <<'EOF' >"$full_path"

position=top-left
alpha=1.0
background_alpha=0.38
background_color=0A0A0A
round_corners=8
text_outline=1
font_size=22
text_color=FFFFFF
gpu_color=00FF00
cpu_color=00FFFF
frametime_color=FFFF00


gpu_name
fps
fps_metrics=avg,0.01,0.001
frametime
frame_timing

cpu_stats
cpu_temp
cpu_power
cpu_mhz

gpu_list=1
gpu_stats
gpu_temp
gpu_power
gpu_core_clock
gpu_mem_clock
gpu_fan

ram
vram
engine_version
vulkan_driver


reload_cfg=Shift_R+F10

legacy_layout=1

hud_layout=
Drv: ${vulkan_driver}
${gpu_name}
GPU: ${gpu_stats}  ${gpu_temp}C  ${gpu_power}W  Fan:${gpu_fan}
GPU Clk: ${gpu_core_clock}  Mem Clk: ${gpu_mem_clock}
CPU: ${cpu_stats}  ${cpu_temp}C  ${cpu_power}W  ${cpu_mhz}MHz
Mem: RAM ${ram}  VRAM ${vram}
FPS: ${fps}  (avg/1%/0.1%)
${frame_timing}
Frametime: ${frametime}
Eng: ${engine_version}
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
    msg_success "Dynamic profiles created. Default is MINIMAL."
    echo ""
    if confirm "⛓️ Do you want to add a Hyprland shortcut to toggle configs?"; then
      local kb_line='bindn = RSHIFT, F10, exec, ~/.config/MangoHud/switch_mangohud.sh # MangoHud layout switch'
      add_to_hypr_config "keybinds" "$kb_line" ""
    fi
  fi

  # Close the config creation if statement
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
  if ! confirm_or_exit "💬 Do you want to install Discord?"; then
    return
  fi

  # Install Discord and dependencies
  msg_step "Installing Discord and dependencies..."
  local discord_packages=("discord" "jq")
  install_packages "pacman" "${discord_packages[@]}"

  echo ""
  if ! confirm "🛠️ Do you want to apply the white update screen fix?"; then
    pause
    return
  fi

  msg_step "Applying Discord white screen fix..."

  # --- Fix 1: Modify settings.json ---
  local config_dir="$HOME/.config/discord"
  local settings_file="$config_dir/settings.json"

  mkdir -p "$config_dir"

  if [[ -f "$settings_file" ]]; then
    if grep -q '"SKIP_HOST_UPDATE": true' "$settings_file"; then
      msg_success "'SKIP_HOST_UPDATE' already set in settings.json"
    else
      msg_info "Patching settings.json..."
      local tmp_file=$(mktemp)
      jq '. + {"SKIP_HOST_UPDATE": true}' "$settings_file" >"$tmp_file" && mv "$tmp_file" "$settings_file"
      msg_success "settings.json patched successfully."
    fi
  else
    msg_info "Creating settings.json..."
    cat <<EOF >"$settings_file"
{
  "SKIP_HOST_UPDATE": true
}
EOF
    msg_success "settings.json created."
  fi

  # --- Fix 2: Modify local desktop entry ---
  local desktop_dir="$HOME/.local/share/applications"
  local desktop_file="$desktop_dir/discord.desktop"

  mkdir -p "$desktop_dir"
  cp /usr/share/applications/discord.desktop "$desktop_file" 2>/dev/null

  if [[ -f "$desktop_file" ]]; then
    sed -i 's|^Exec=.*|Exec=env QT_QPA_PLATFORM=xcb /usr/bin/discord|' "$desktop_file"
    msg_success "Desktop file updated."
  else
    msg_warning "Could not find system discord.desktop to copy."
  fi

  msg_info "Updating desktop database..."
  update-desktop-database "$desktop_dir"

  msg_success "🎉 Discord is installed and fixed!"
  pause
}

##################################### 🌸 SPOTIFY & SPICETIFY
install_spotify_spicetify() {
  echo ""
  msg_info "🎵 This will install Spotify and patch it using Spicetify CLI + Marketplace."

  if ! confirm_or_exit "Continue with Spotify & Spicetify installation?"; then
    return
  fi

  # Install Spotify and Spicetify CLI
  msg_step "Installing Spotify and Spicetify CLI..."
  local spotify_packages=("spotify" "spicetify-cli")
  install_packages "aur" "${spotify_packages[@]}"

  # Apply permissions to /opt/spotify
  msg_step "Applying permissions to /opt/spotify..."
  sudo chmod a+wr /opt/spotify
  sudo chmod a+wr /opt/spotify/Apps -R
  msg_success "Spotify permissions applied."

  # Install Spicetify Marketplace
  msg_step "Installing Spicetify Marketplace..."
  if curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh; then
    msg_success "Spicetify Marketplace installed."
  else
    msg_warning "Spicetify Marketplace installation may have failed."
  fi

  # Run spicetify backup + apply
  msg_step "Running spicetify backup + apply..."
  spicetify backup apply

  if [[ $? -eq 0 ]]; then
    msg_success "✅ Spotify and Spicetify successfully installed and patched!"
  else
    msg_warning "Spicetify backup/apply may have encountered issues."
  fi

  pause
}

##################################### 🌸 LIB32 MULTIMEDIA
install_lib32_multimedia() {
  echo ""
  msg_info "🎮 This will install essential lib32 multimedia libraries for better audio/video support in some games."
  msg_warning "This is especially useful for games like Resident Evil 2 Remake and Days Gone Remastered."
  msg_warning "⏳ The installation can take a while (~30 minutes depending on your system and internet speed)."

  if ! confirm_or_exit "Do you want to continue with lib32 multimedia installation?"; then
    return
  fi

  # Define lib32 multimedia packages
  local lib32_packages=(
    "lib32-gstreamer"
    "lib32-gst-plugins-base"
    "lib32-gst-plugins-good"
    "lib32-gst-plugins-bad"
    "lib32-gst-plugins-ugly"
    "lib32-libva"
    "lib32-libx264"
    "lib32-libvpx"
    "lib32-libmpeg2"
    "lib32-openal"
    "lib32-libpulse"
    "lib32-ffmpeg"
    "lib32-vulkan-icd-loader"
  )

  msg_step "Installing lib32 multimedia libraries..."
  if install_packages "aur" "${lib32_packages[@]}"; then
    msg_success "All lib32 multimedia libraries have been installed!"
  else
    msg_warning "Some packages may have failed to install. Check the output above."
  fi

  pause
}

##################################### 🌸 INSTALL GAMEMODE
install_gamemode_section() {
  echo ""
  if ! confirm_or_exit "Do you want to install and configure Gamemode?"; then
    return
  fi

  # Step 1: Install gamemode
  msg_step "Step 1: Installing Gamemode packages"
  local gamemode_packages=("gamemode" "lib32-gamemode")
  install_packages "pacman" "${gamemode_packages[@]}"

  # Step 2: Add user to gamemode group
  msg_step "Step 2: Configuring user permissions"
  if groups $(whoami) | grep -qw "gamemode"; then
    msg_success "You are already part of the 'gamemode' group."
  else
    msg_info "Adding current user to 'gamemode' group..."
    for group in "${GAMEMODE_GROUPS[@]}"; do
      sudo usermod -aG "$group" $(whoami)
    done
    msg_success "User added to '${GAMEMODE_GROUPS[*]}' group(s)."
  fi

  # Step 3: Check if gamemoded is running
  msg_step "Step 3: Checking gamemoded service status"
  if systemctl --user is-active --quiet gamemoded; then
    msg_success "Gamemoded is running under user session."
  elif systemctl is-active --quiet gamemoded; then
    msg_success "Gamemoded is running (system level)."
  else
    msg_warning "Gamemoded is not currently active."
    msg_info "Trying to start it manually..."

    systemctl --user start gamemoded 2>/dev/null || sudo systemctl start gamemoded

    if systemctl --user is-active --quiet gamemoded || systemctl is-active --quiet gamemoded; then
      msg_success "Gamemoded started successfully!"
    else
      msg_warning "Could not start gamemoded. Try rebooting or launching it with 'gamemoded -d'."
    fi
  fi

  echo ""
  msg_success "🎉 Gamemode is installed and configured!"
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


#################################### 🌸 REAKJRA'S HYPR MENU
reakjra_hypr_menu() {
  while true; do
    clear
    echo ""
    msg_section "Reakjra's Hypr 🌸"
    echo ""
    msg_info "This will import custom Hyprland configurations for each ricing setup."
    msg_info "All configurations are Reakjra's personal setups and preferences."
    echo ""
    echo "1. 🏠 HyDE Configuration"
    echo "2. 🔚 End4 Configuration"
    echo "3. 👈 Back to main menu"
    echo ""
    read -p "Choose an option: " choice

    case "$choice" in
    1) hyde_config_menu ;;
    2) end4_config_menu ;;
    3) break ;;
    *) echo "❌ Invalid option." ;;
    esac
  done
}

#################################### 🌸 HYDE CONFIGURATION MENU
hyde_config_menu() {
  while true; do
    clear
    echo ""
    msg_section "HyDE Configuration 🌸"
    echo ""
    echo "1. 🍼 Import userprefs.conf (it will override the current one)"
    echo "2. 🍼 Import windowrules.conf (it will override the current one)"
    echo "3. 🍼 Import Reakjra's Waybar settings"
    echo "4. 🍼 Apply wallbash theme to Visual Studio Code"
    echo "5. 👈 Back to Reakjra's Hypr menu"
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

#################################### 🌸 END4 CONFIGURATION MENU
end4_config_menu() {
  clear
  echo ""
  msg_section "End4 Configuration 🌸"
  echo ""
  msg_info "🚧 Working on it..."
  msg_info "End4 configurations are currently being developed and will be available soon!"
  echo ""
  echo "1. 👈 Back to Reakjra's Hypr menu"
  echo ""
  read -p "Choose an option: " choice

  case "$choice" in
  1) return ;;
  *)
    msg_warning "Invalid option."
    sleep 1
    end4_config_menu
    ;;
  esac
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
  if confirm "Do you want to clean pacman cache?"; then
    local logfile=$(create_log "clean_pacman_cache")
    msg_step "Cleaning pacman cache..."

    if sudo pacman -Sc --noconfirm | tee "$logfile"; then
      msg_success "Pacman cache cleaned successfully."
      msg_info "Log saved: $logfile"
    else
      msg_error "Failed to clean pacman cache."
    fi
  else
    msg_info "Pacman cache cleaning skipped."
  fi
  pause
}

####################################
clean_yay_cache() {
  echo ""
  if confirm "Do you want to clean $AUR_HELPER cache?"; then
    local logfile=$(create_log "clean_${AUR_HELPER}_cache")
    msg_step "Cleaning $AUR_HELPER cache..."

    if "$AUR_HELPER" -Sc --noconfirm | tee "$logfile"; then
      msg_success "$AUR_HELPER cache cleaned successfully."
      msg_info "Log saved: $logfile"
    else
      msg_error "Failed to clean $AUR_HELPER cache."
    fi
  else
    msg_info "$AUR_HELPER cache cleaning skipped."
  fi
  pause
}

####################################
remove_orphans() {
  echo ""
  msg_step "Searching for orphaned packages..."

  local orphans
  orphans=$(pacman -Qtdq 2>/dev/null)

  if [[ -z "$orphans" ]]; then
    msg_success "No orphaned packages found!"
  else
    echo ""
    msg_warning "🧺 Orphans found:"
    echo -e "${CYAN}$orphans${RESET}"
    echo ""

    if confirm "Remove these orphaned packages?"; then
      local logfile=$(create_log "remove_orphans")
      echo "$orphans" >"$logfile"

      msg_step "Removing orphaned packages..."
      if sudo pacman -Rns $orphans; then
        msg_success "Orphaned packages removed successfully."
        msg_info "Orphan removal log saved at $logfile"
      else
        msg_error "Failed to remove some orphaned packages."
      fi
    else
      msg_info "Orphan removal skipped."
    fi
  fi
  pause
}

####################################
full_update() {
  echo ""
  msg_section "Running full system update..."

  local logfile=$(create_log "full_update")

  msg_step "Updating official repositories (pacman)..."
  {
    echo "=== PACMAN UPDATE ==="
    sudo pacman -Syu --noconfirm
    echo ""
    echo "=== AUR UPDATE ($AUR_HELPER) ==="
    "$AUR_HELPER" -Syu --noconfirm
  } | tee "$logfile"

  if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
    msg_success "System update completed successfully!"
  else
    msg_warning "System update completed with some warnings or errors."
  fi

  msg_info "Update log saved: $logfile"
  pause
}

check_cache_sizes() {
  echo ""
  msg_step "Checking cache sizes..."

  echo ""
  msg_info "📦 Pacman cache size:"
  du -sh /var/cache/pacman/pkg 2>/dev/null || msg_warning "Could not access pacman cache directory."

  echo ""
  msg_info "📦 $AUR_HELPER cache size:"
  du -sh ~/.cache/"$AUR_HELPER" 2>/dev/null || du -sh ~/.cache/yay 2>/dev/null || msg_warning "Could not access $AUR_HELPER cache directory."

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
  echo -e "⚠️ These settings are tuned for a 2-fan GPU (e.g., 3060 Ti). Adjust only if you know what you're doing. Mind the Power Limit is set to ${NVIDIA_POWER_LIMIT}w. Change it in ${CYAN}reakjra.conf.sh${RESET} if you need to."
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
  msg_step "Step 4: Create undervolt script (gpu-limit.sh)"
  if confirm "Create gpu-limit.sh?"; then
    cat >~/gpu-limit.sh <<EOF
#!/bin/bash
sudo nvidia-smi -pl ${NVIDIA_POWER_LIMIT}
EOF
    sudo chmod +x ~/gpu-limit.sh
    msg_success "gpu-limit.sh created and made executable."
  fi

  # Step 5: Create fan curve control script
  msg_step "Step 5: Create fan curve script (nvidia_fan_control.sh)"
  if confirm "Create fan control script?"; then
    cat >~/nvidia_fan_control.sh <<EOF
#!/bin/bash

LOG_FILE="/tmp/nvidia_fan_control.log"
> "\$LOG_FILE"
exec > >(tee -a "\$LOG_FILE") 2>&1

FAN_CURVE=(
$(printf '    "%s"\n' "${NVIDIA_FAN_CURVE[@]}")
)
INTERVAL_SECONDS=${NVIDIA_FAN_INTERVAL}</EOF

run_nvidia_settings() {
    export DISPLAY="${DISPLAY:-:0}"
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    sudo env DISPLAY="$DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" nvidia-settings "$@"
}

get_gpu_temp() {
    nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader
}

set_fan_speed() {
    local speed_percent=\$1
    local fans_to_control=($(printf '"%s" ' "${NVIDIA_FAN_IDS[@]}"))
    for fan_id in "\${fans_to_control[@]}"; do
        run_nvidia_settings -a "[fan:\${fan_id}]/GPUTargetFanSpeed=\${speed_percent}"
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
    sleep "\$INTERVAL_SECONDS"
done
EOF
    sudo chmod +x ~/nvidia_fan_control.sh
    msg_success "nvidia_fan_control.sh created and made executable."
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
  msg_step "Step 7: Autostart configuration for Hyprland"
  if confirm "Automatically start the fan and power limit scripts on boot?"; then
    add_to_hypr_config "execs" "exec = ~/gpu-limit.sh" "NVIDIA GPU Scripts"
    add_to_hypr_config "execs" 'exec-once = bash -c "sleep 1 && xhost +si:localuser:root && sleep 2 && ~/nvidia_fan_control.sh &"' ""
  else
    msg_warning "Skipping autostart. You'll need to launch the scripts manually."
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

##################################### AMD RELATED

amd_menu() {
  while true; do
    clear
    echo ""
    echo -e "🌸${RED} AMD Personal Configuration 🌸 ${RESET} "
    echo ""
    echo "1. 🐧 Install Zen Kernel (AMD)"
    echo "2. 🔴 Install AMD Drivers & Utils"
    echo "3. 🌡️ Install LACT (Linux AMDGPU Control Tool)"
    echo "4. 🤖 Install Ollama-ROCm"
    echo "5. 👈 Back to main menu"
    echo ""
    read -p "Choose an option: " choice

    case "$choice" in
    1) install_zen_kernel_amd ;;
    2) install_amd_drivers_utils ;;
    3) install_lact ;;
    4) install_ollama_rocm ;;
    5) break ;;
    *) echo "❌ Invalid option." ;;
    esac
  done
}

####################################
install_zen_kernel_amd() {
  echo ""
  read -p "🌸 Do you want to install the Linux-Zen Kernel for AMD? (y/n): " confirm
  [[ "$confirm" != "y" ]] && return

  echo ""
  echo "🐧 Installing Linux-Zen Kernel and headers..."
  sudo pacman -S --noconfirm linux-zen linux-zen-headers

  echo ""
  echo "🔴 Installing AMD microcode for better performance..."
  sudo pacman -S --noconfirm amd-ucode

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

####################################
install_amd_drivers_utils() {
  clear
  msg_section "AMD Drivers Installation 🌸"
  echo ""
  msg_info "This will install essential AMD GPU drivers for optimal performance."
  echo ""
  msg_info "This includes: ${CYAN}mesa, xf86-video-amdgpu, vulkan-radeon, and lib32 variants${RESET}"
  echo

  # Install AMD drivers
  msg_step "Installing AMD graphics drivers..."
  if confirm "Install AMD graphics drivers?"; then
    local amd_drivers=(
      "mesa"
      "xf86-video-amdgpu"
      "vulkan-radeon"
      "lib32-mesa"
      "lib32-vulkan-radeon"
      "lib32-vulkan-icd-loader"
    )

    if install_packages "pacman" "${amd_drivers[@]}"; then
      msg_success "All AMD graphics drivers installed successfully!"
    else
      msg_warning "Some packages may have failed to install. Check the output above."
    fi
  else
    msg_info "Skipping AMD graphics drivers."
  fi

  echo ""
  msg_success "AMD drivers installation complete!"
  echo ""
  pause
}

####################################
install_lact() {
  clear
  msg_section "LACT (Linux AMDGPU Control Tool) Installation 🌸"
  echo ""
  msg_info "LACT is a Linux AMDGPU Control application for controlling fans, temperature, power, and overclocking."
  echo ""
  msg_warning "LACT requires GPU access permissions and systemd service configuration."
  echo ""

  # Check if LACT is already installed
  if check_package "lact"; then
    msg_success "LACT is already installed."
    if ! confirm "Do you want to reinstall/reconfigure it?" false; then
      return
    fi
  fi

  # Step 1: Install LACT
  msg_step "Step 1: Install LACT"
  if confirm_or_exit "Install LACT from AUR?"; then
    if ! install_package "lact" "aur"; then
      msg_error "Cannot proceed without LACT installation."
      pause
      return
    fi
  fi

  # Step 2: Configure permissions
  msg_step "Step 2: Configure GPU access permissions"
  if confirm "Add user to necessary groups for GPU access?"; then
    sudo usermod -aG render,video $(whoami)
    msg_success "User added to render and video groups."
    msg_info "You may need to log out and back in for group changes to take effect."
  fi

  # Step 3: Enable and start LACT daemon
  msg_step "Step 3: Configure LACT daemon"
  if confirm "Enable and start LACT daemon?"; then
    if manage_service "enable-now" "lactd"; then
      check_service_status "lactd"
    fi
  else
    msg_warning "LACT daemon not enabled. Manual configuration required."
  fi

  echo ""
  msg_success "LACT installation and configuration complete!"
  msg_info "Use LACT to control fan curves, power limits, and monitor GPU stats."
  echo ""
  pause
}

####################################
install_ollama_rocm() {
  clear
  msg_section "Ollama-ROCm Installation 🌸"
  echo ""
  msg_info "This will install Ollama with ROCm support for AMD GPU acceleration."
  echo ""

  # Check if already installed
  if check_package "ollama-rocm"; then
    msg_success "Ollama-ROCm is already installed."
    pause
    return
  fi

  # Install ollama-rocm
  msg_step "Installing Ollama-ROCm..."
  if confirm_or_exit "Install Ollama-ROCm package?"; then
    if install_package "ollama-rocm" "pacman"; then
      msg_success "Ollama-ROCm installation complete!"
      msg_info "Ollama should now be able to use your AMD GPU for AI inference."
    fi
  fi

  echo ""
  pause
}


##################################### 🔁 MAIN MENU LOOP
while true; do
  main_menu
done

