#!/bin/bash

mount_drives_section() {
    echo ""
    read -p "📦 Do you want to proceed with the partition mounting section? (y/n): " do_mount
    if [[ "$do_mount" != "y" ]]; then
        return
    fi

    echo "🔍 Scanning available partitions..."

    mapfile -t PARTS < <(lsblk -P -o NAME,SIZE,UUID,FSTYPE,MOUNTPOINT,TYPE)

    echo ""
    echo "🔢 Available partitions:"
    INDEXED_PARTS=()
    index=1

    for line in "${PARTS[@]}"; do
        eval "$line" # Parses NAME=xxx SIZE=xxx ... into variables

        # Skip non-partitions (e.g., disks like nvme0n1)
        if [[ "$TYPE" != "part" ]]; then
            continue
        fi

        mount_status=""
        if [[ -n "$MOUNTPOINT" ]]; then
            if [[ "$MOUNTPOINT" == "/" ]]; then
                mount_status="🌸 Already mounted  → /  (this is your Linux system partition)"
            else
                mount_status="🌸 Already mounted  → $MOUNTPOINT"
            fi
        fi

        # Format UUID and FSTYPE if missing
        UUID="${UUID:-N/A}"
        FSTYPE="${FSTYPE:-unknown}"

        printf "%2d. %-15s %-8s UUID: %-36s Type: %-8s  %s\n" \
            "$index" "$NAME" "$SIZE" "$UUID" "$FSTYPE" "$mount_status"

        INDEXED_PARTS+=("$NAME|$UUID|$FSTYPE|$MOUNTPOINT")
        ((index++))
    done

    if [[ "${#INDEXED_PARTS[@]}" -eq 0 ]]; then
        echo "🚫 No usable partitions found."
        return
    fi

    echo ""
    read -p "👉 Enter the partition numbers you want to mount (e.g. 1,3,4): " selections

    # Ensure ntfs-3g is installed
    if ! command -v ntfs-3g &> /dev/null; then
        echo "📦 'ntfs-3g' not found. Installing..."
        sudo pacman -S --noconfirm ntfs-3g
    fi

    IFS=',' read -ra SELECTED <<< "$selections"
    for sel in "${SELECTED[@]}"; do
        idx=$((sel - 1))
        if [[ -z "${INDEXED_PARTS[$idx]}" ]]; then
            echo "⚠️  Partition $sel is invalid, skipping."
            continue
        fi

        IFS="|" read -r name uuid fstype mountpoint <<< "${INDEXED_PARTS[$idx]}"
        dev="/dev/$name"
        mount_dir=~/"$name"

        if [[ -n "$mountpoint" ]]; then
            if [[ "$mountpoint" == "/" ]]; then
                echo "⚠️  $name is your Linux system partition, skipping."
            else
                echo "⚠️  $name is already mounted at $mountpoint, skipping."
            fi
            continue
        fi

        echo "🔗 Mounting $name to $mount_dir..."
        mkdir -p "$mount_dir"

        if [[ "$fstype" == "ntfs" ]]; then
            sudo mount -t ntfs-3g "$dev" "$mount_dir" -o uid=$(id -u),gid=$(id -g)
        else
            sudo mount "$dev" "$mount_dir"
        fi

        read -p "📝 Add $name to /etc/fstab for auto-mount on boot? (y/n): " add_fstab
        if [[ "$add_fstab" == "y" ]]; then
            username=$(whoami)
            fstab_entry="UUID=${uuid} /home/${username}/${name} ntfs-3g defaults,uid=1000,gid=1000,rw,user,exec,umask=000 0 0"
            echo "$fstab_entry" | sudo tee -a /etc/fstab > /dev/null
            echo "✅ Added to /etc/fstab"
        fi
    done

    echo ""
    echo "🎉 Partition mounting section completed!"
}

mount_drives_section
