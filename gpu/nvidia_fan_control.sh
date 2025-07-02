#!/bin/bash


# --- Logging Setup ---
LOG_FILE="/tmp/nvidia_fan_control.log"
# Clear the log file on each run for a fresh start
> "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "$(date): Script started."
# --- End Logging Setup ---

# --- Configuration ---
# Define the fan curve (temperature: fan_speed_percentage)
# Example: 40C at 30%, 50C at 40%, etc.
FAN_CURVE=(
    "40:30"   # Up to 40C, 30% fan speed
    "50:40"   # Up to 50C, 40% fan speed
    "60:50"   # Up to 60C, 60% fan speed
    "70:65"   # Up to 70C, 65% fan speed
    "75:70"   # Up to 75C, 70% fan speed
    "80:75"   # Up to 80C, 75% fan speed
    "90:100"  # Above 90C, 100% fan speed
)
INTERVAL_SECONDS=5 # How often to check temperature (in seconds)

# --- Important Prerequisites (READ CAREFULLY!) ---
# 1. Ensure NVIDIA Proprietary Drivers are installed.
# 2. Set 'Coolbits "31"' in your xorg.conf file (e.g., /etc/X11/xorg.conf.d/20-nvidia.conf).
#    Example content for 20-nvidia.conf:
#    Section "Device"
#        Identifier "Nvidia Card"
#        Driver     "nvidia"
#        VendorName "NVIDIA Corporation"
#        Option     "Coolbits" "31"
#    EndSection
# 4. This script uses 'sudo' for nvidia-settings.
#    - For manual testing, you'll need to run 'xhost +si:localuser:root' in your terminal first.
# ---

# --- Do not modify below this line unless you know what you're doing ---

# Function to run nvidia-settings command with necessary environment for Wayland/Xwayland
# This ensures nvidia-settings can connect to your display when run with elevated privileges.
run_nvidia_settings() {
    export DISPLAY="${DISPLAY:-:0}"
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" 

    sudo env DISPLAY="$DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" nvidia-settings "$@"
}

# Function to get GPU temperature
get_gpu_temp() {
    nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader
}

# Function to set fan speed for all relevant fans
set_fan_speed() {
    local speed_percent=$1
    echo "Setting fan speed to ${speed_percent}%..."
    
    local fans_to_control=("0" "1") # Add more fan numbers if your GPU has more fans

    for fan_id in "${fans_to_control[@]}"; do
        run_nvidia_settings -a "[fan:${fan_id}]/GPUTargetFanSpeed=${speed_percent}"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to set fan speed for fan:${fan_id} to ${speed_percent}%. Check logs."
            # Continue trying for other fans/next loop iteration
        fi
    done
}

# Main loop
echo "Starting NVIDIA GPU Fan Control Script..."
echo "Monitoring GPU temperature every ${INTERVAL_SECONDS} seconds."
echo "Press Ctrl+C to stop."

# --- Initial setup: Enable manual fan control ---

echo "Attempting to enable manual GPU fan control (GPUFanControlState=1)..."
run_nvidia_settings -a "[gpu:0]/GPUFanControlState=1"
if [ $? -ne 0 ]; then
    echo "CRITICAL ERROR: Failed to enable manual fan control. This is required for fan control to work."
    echo "Ensure 'coolbits=31' is enabled and you have proper permissions for nvidia-settings."
    exit 1 
else
    echo "Manual fan control enabled."
fi
# --- End of initial setup ---


while true; do
    GPU_TEMP=$(get_gpu_temp)

    if [[ -z "$GPU_TEMP" ]]; then
        echo "Error: Could not retrieve GPU temperature. Is nvidia-smi installed and drivers working?"
        sleep "$INTERVAL_SECONDS"
        continue
    fi

    # Determine target fan speed based on curve
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
