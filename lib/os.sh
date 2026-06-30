#!/bin/bash

declare -A OS_NAMES=(
    ["1"]="Ubuntu 22.04 (Jammy)"
    ["2"]="Ubuntu 24.04 (Noble)"
    ["3"]="Debian 12 (Bookworm)"
    ["4"]="CentOS Stream 9"
    ["5"]="AlmaLinux 9"
)

declare -A OS_URLS=(
    ["1"]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    ["2"]="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    ["3"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    ["4"]="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-9-x86_64-latest.qcow2"
    ["5"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
)

declare -A OS_FILES=(
    ["1"]="jammy-server-cloudimg-amd64.img"
    ["2"]="noble-server-cloudimg-amd64.img"
    ["3"]="debian-12-generic-amd64.qcow2"
    ["4"]="CentOS-Stream-9-x86_64-latest.qcow2"
    ["5"]="AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
)

draw_os_menu() {
    echo "  Select Operating System:"
    echo ""
    for key in $(echo "${!OS_NAMES[@]}" | tr ' ' '\n' | sort -n); do
        echo "  [$key] ${OS_NAMES[$key]}"
    done
    echo ""
}

get_os_image_path() {
    local os_choice="$1"
    local filename="${OS_FILES[$os_choice]}"
    echo "$IMAGE_DIR/$filename"
}

ensure_os_image() {
    local os_choice="$1"
    local url="${OS_URLS[$os_choice]}"
    local filename="${OS_FILES[$os_choice]}"
    local dest="$IMAGE_DIR/$filename"

    if [[ -f "$dest" ]]; then
        log_msg "INFO" "OS image already cached: $dest"
        echo "$dest"
        return 0
    fi

    echo "  Downloading ${OS_NAMES[$os_choice]}..."
    echo "  URL: $url"
    log_msg "INFO" "Downloading OS image: $url"

    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$dest" "$url" 2>&1
    elif command -v curl &>/dev/null; then
        curl -fSL -o "$dest" "$url" 2>&1
    else
        echo "ERROR: Neither wget nor curl is available." >&2
        return 1
    fi

    if [[ ! -f "$dest" ]]; then
        echo "ERROR: Failed to download OS image." >&2
        log_msg "ERROR" "Failed to download: $url"
        return 1
    fi

    local size
    size=$(du -h "$dest" | awk '{print $1}')
    echo "  Downloaded: $filename ($size)"
    log_msg "INFO" "OS image downloaded: $dest ($size)"
    echo "$dest"
    return 0
}

create_vm_disk() {
    local backing_image="$1"
    local disk_path="$2"
    local disk_gb="$3"

    qemu-img create -f qcow2 -b "$backing_image" -F qcow2 "$disk_path" "${disk_gb}G" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to create disk image." >&2
        log_msg "ERROR" "qemu-img create failed for $disk_path"
        return 1
    fi

    log_msg "INFO" "Created disk: $disk_path (${disk_gb}G backing: $backing_image)"
    echo "$disk_path"
}