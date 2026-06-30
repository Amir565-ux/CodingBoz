#!/bin/bash

vps_create() {
    echo ""
    echo "--------------- Create VPS ---------------"
    echo ""

    local hostname username password ram cpu disk ssh_port os_choice
    local error

    while true; do
        hostname=$(prompt "  Hostname: ")
        error=$(validate_hostname "$hostname")
        if [[ -n "$error" ]]; then
            echo "  $error"
            continue
        fi
        error=$(check_duplicate_hostname "$hostname")
        if [[ -n "$error" ]]; then
            echo "  $error"
            continue
        fi
        break
    done

    while true; do
        username=$(prompt "  Username [root]: ")
        username="${username:-root}"
        error=$(validate_username "$username")
        if [[ -n "$error" ]]; then
            echo "  $error"
            continue
        fi
        break
    done

    while true; do
        password=$(prompt_password "  Password: ")
        error=$(validate_password "$password")
        if [[ -n "$error" ]]; then
            echo "  $error"
            continue
        fi
        local password_confirm
        password_confirm=$(prompt_password "  Confirm Password: ")
        if [[ "$password" != "$password_confirm" ]]; then
            echo "  ERROR: Passwords do not match."
            continue
        fi
        break
    done

    while true; do
        ram=$(prompt "  RAM (MB) [1024]: ")
        ram="${ram:-1024}"
        error=$(validate_ram "$ram")
        if [[ -n "$error" ]]; then
            echo "  $error"
            continue
        fi
        break
    done

    while true; do
        disk=$(prompt "  Disk (GB) [20]: ")
        disk="${disk:-20}"
        error=$(validate_disk "$disk")
        if [[ -n "$error" ]]; then
            echo "  $error"
            continue
        fi
        break
    done

    while true; do
        cpu=$(prompt "  CPU Cores [1]: ")
        cpu="${cpu:-1}"
        error=$(validate_cpu "$cpu")
        if [[ -n "$error" ]]; then
            echo "  $error"
            continue
        fi
        break
    done

    while true; do
        ssh_port=$(prompt "  SSH Port: ")
        error=$(validate_port "$ssh_port")
        if [[ -n "$error" ]]; then
            echo "  $error"
            continue
        fi
        error=$(check_duplicate_port "$ssh_port")
        if [[ -n "$error" ]]; then
            echo "  $error"
            continue
        fi
        break
    done

    echo ""
    draw_os_menu
    while true; do
        os_choice=$(prompt "  Select OS [1]: ")
        os_choice="${os_choice:-1}"
        if [[ -z "${OS_NAMES[$os_choice]}" ]]; then
            echo "  ERROR: Invalid selection."
            continue
        fi
        break
    done

    echo ""
    echo "  Creating VPS '$hostname'..."
    log_msg "INFO" "Creating VPS: $hostname"

    local vps_id
    vps_id=$(get_next_id)

    local vm_name="${VPS_PREFIX}${hostname}"
    local disk_path="$DISK_DIR/${hostname}.qcow2"
    local mac_addr
    mac_addr=$(generate_mac)

    local ip_addr
    ip_addr=$(allocate_ip)
    if [[ $? -ne 0 ]]; then
        echo "  $ip_addr"
        press_enter
        return 1
    fi

    local backing_image
    backing_image=$(ensure_os_image "$os_choice")
    if [[ $? -ne 0 ]]; then
        echo "  Failed to prepare OS image."
        release_ip "$ip_addr"
        press_enter
        return 1
    fi

    local created_disk
    created_disk=$(create_vm_disk "$backing_image" "$disk_path" "$disk")
    if [[ $? -ne 0 ]]; then
        echo "  $created_disk"
        release_ip "$ip_addr"
        press_enter
        return 1
    fi

    local seed_iso
    seed_iso=$(generate_cloud_init "$vps_id" "$hostname" "$username" "$password" "$ip_addr")
    if [[ $? -ne 0 ]]; then
        echo "  $seed_iso"
        rm -f "$disk_path"
        release_ip "$ip_addr"
        press_enter
        return 1
    fi

    local xml_path
    xml_path=$(generate_vm_xml "$vm_name" "$ram" "$cpu" "$disk_path" "$seed_iso" "$mac_addr")
    if [[ $? -ne 0 ]]; then
        echo "  $xml_path"
        rm -f "$disk_path" "$seed_iso"
        rm -rf "$CLOUDINIT_DIR/$hostname"
        release_ip "$ip_addr"
        press_enter
        return 1
    fi

    virsh define "$xml_path" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "  ERROR: Failed to define VM with libvirt."
        rm -f "$disk_path" "$seed_iso" "$xml_path"
        rm -rf "$CLOUDINIT_DIR/$hostname"
        release_ip "$ip_addr"
        log_msg "ERROR" "virsh define failed for $vm_name"
        press_enter
        return 1
    fi

    add_port_forward "$ssh_port" "$ip_addr"

    local config_path
    config_path=$(get_vps_config_path "$vps_id")
    cat > "$config_path" <<CONF
HOSTNAME=$hostname
USERNAME=$username
RAM=$ram
DISK=$disk
CPU=$cpu
SSH_PORT=$ssh_port
OS=${OS_NAMES[$os_choice]}
MAC=$mac_addr
IP_ADDR=$ip_addr
VM_NAME=$vm_name
DISK_PATH=$disk_path
SEED_ISO=$seed_iso
XML_PATH=$xml_path
CONF

    increment_id

    echo "  VPS '$hostname' created successfully (ID: $vps_id)."
    echo "  IP: $ip_addr | SSH Port: $ssh_port"
    log_msg "INFO" "VPS created: $hostname (ID: $vps_id, IP: $ip_addr, Port: $ssh_port)"
    press_enter
}

vps_start() {
    echo ""
    echo "--------------- Start VPS ----------------"
    echo ""

    local ids
    ids=$(get_all_vps_ids)
    if [[ -z "$ids" ]]; then
        echo "  No VPS found."
        press_enter
        return
    fi

    draw_vps_table
    echo ""

    local vps_id
    vps_id=$(prompt "  Enter VPS ID: ")
    if ! validate_positive_int "$vps_id"; then
        echo "  ERROR: Invalid ID."
        press_enter
        return
    fi

    local err
    err=$(validate_vps_id_exists "$vps_id")
    if [[ -n "$err" ]]; then
        echo "  $err"
        press_enter
        return
    fi

    local vm_name
    vm_name=$(get_vps_value "$vps_id" "VM_NAME")
    local hostname
    hostname=$(get_vps_value "$vps_id" "HOSTNAME")
    local state
    state=$(virsh domstate "$vm_name" 2>/dev/null)

    if [[ "$state" == "running" ]]; then
        echo "  VPS '$hostname' is already running. Attaching to console..."
    else
        echo "  Starting VPS '$hostname'..."
        virsh start "$vm_name" >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            echo "  ERROR: Failed to start VPS."
            log_msg "ERROR" "Failed to start VPS: $vm_name"
            press_enter
            return
        fi
        log_msg "INFO" "Started VPS: $vm_name"
        echo "  VPS started. Attaching to console..."
        sleep 2
    fi

    echo ""
    echo "  Press Ctrl+] to exit console."
    echo ""
    sleep 1
    virsh console "$vm_name"
    echo ""
    echo "  Disconnected from console."
    log_msg "INFO" "Disconnected from console: $vm_name"
    press_enter
}

vps_stop() {
    echo ""
    echo "---------------- Stop VPS ----------------"
    echo ""

    local ids
    ids=$(get_all_vps_ids)
    if [[ -z "$ids" ]]; then
        echo "  No VPS found."
        press_enter
        return
    fi

    draw_vps_table
    echo ""

    local vps_id
    vps_id=$(prompt "  Enter VPS ID: ")
    if ! validate_positive_int "$vps_id"; then
        echo "  ERROR: Invalid ID."
        press_enter
        return
    fi

    local err
    err=$(validate_vps_id_exists "$vps_id")
    if [[ -n "$err" ]]; then
        echo "  $err"
        press_enter
        return
    fi

    local vm_name hostname state
    vm_name=$(get_vps_value "$vps_id" "VM_NAME")
    hostname=$(get_vps_value "$vps_id" "HOSTNAME")
    state=$(virsh domstate "$vm_name" 2>/dev/null)

    if [[ "$state" != "running" ]]; then
        echo "  VPS '$hostname' is not running."
        press_enter
        return
    fi

    echo "  Stopping VPS '$hostname'..."
    virsh shutdown "$vm_name" >/dev/null 2>&1

    local wait=0
    while (( wait < 30 )); do
        state=$(virsh domstate "$vm_name" 2>/dev/null)
        if [[ "$state" != "running" ]]; then
            break
        fi
        sleep 1
        ((wait++))
    done

    state=$(virsh domstate "$vm_name" 2>/dev/null)
    if [[ "$state" == "running" ]]; then
        echo "  Graceful shutdown timed out. Force stopping..."
        virsh destroy "$vm_name" >/dev/null 2>&1
    fi

    echo "  VPS '$hostname' stopped."
    log_msg "INFO" "Stopped VPS: $vm_name"
    press_enter
}

vps_restart() {
    echo ""
    echo "-------------- Restart VPS ---------------"
    echo ""

    local ids
    ids=$(get_all_vps_ids)
    if [[ -z "$ids" ]]; then
        echo "  No VPS found."
        press_enter
        return
    fi

    draw_vps_table
    echo ""

    local vps_id
    vps_id=$(prompt "  Enter VPS ID: ")
    if ! validate_positive_int "$vps_id"; then
        echo "  ERROR: Invalid ID."
        press_enter
        return
    fi

    local err
    err=$(validate_vps_id_exists "$vps_id")
    if [[ -n "$err" ]]; then
        echo "  $err"
        press_enter
        return
    fi

    local vm_name hostname state
    vm_name=$(get_vps_value "$vps_id" "VM_NAME")
    hostname=$(get_vps_value "$vps_id" "HOSTNAME")
    state=$(virsh domstate "$vm_name" 2>/dev/null)

    if [[ "$state" != "running" ]]; then
        echo "  VPS '$hostname' is not running. Starting instead..."
        virsh start "$vm_name" >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            echo "  ERROR: Failed to start VPS."
            log_msg "ERROR" "Failed to start VPS for restart: $vm_name"
            press_enter
            return
        fi
        echo "  VPS '$hostname' started."
        log_msg "INFO" "Started VPS (restart): $vm_name"
        press_enter
        return
    fi

    echo "  Restarting VPS '$hostname'..."
    virsh reboot "$vm_name" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "  ACPI reboot not supported. Force restarting..."
        virsh destroy "$vm_name" >/dev/null 2>&1
        sleep 2
        virsh start "$vm_name" >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            echo "  ERROR: Failed to restart VPS."
            log_msg "ERROR" "Failed to force restart VPS: $vm_name"
            press_enter
            return
        fi
    fi

    echo "  VPS '$hostname' restarted."
    log_msg "INFO" "Restarted VPS: $vm_name"
    press_enter
}

vps_delete() {
    echo ""
    echo "-------------- Delete VPS ----------------"
    echo ""

    local ids
    ids=$(get_all_vps_ids)
    if [[ -z "$ids" ]]; then
        echo "  No VPS found."
        press_enter
        return
    fi

    draw_vps_table
    echo ""

    local vps_id
    vps_id=$(prompt "  Enter VPS ID: ")
    if ! validate_positive_int "$vps_id"; then
        echo "  ERROR: Invalid ID."
        press_enter
        return
    fi

    local err
    err=$(validate_vps_id_exists "$vps_id")
    if [[ -n "$err" ]]; then
        echo "  $err"
        press_enter
        return
    fi

    local vm_name hostname ip_addr ssh_port disk_path seed_iso xml_path ci_dir
    vm_name=$(get_vps_value "$vps_id" "VM_NAME")
    hostname=$(get_vps_value "$vps_id" "HOSTNAME")
    ip_addr=$(get_vps_value "$vps_id" "IP_ADDR")
    ssh_port=$(get_vps_value "$vps_id" "SSH_PORT")
    disk_path=$(get_vps_value "$vps_id" "DISK_PATH")
    seed_iso=$(get_vps_value "$vps_id" "SEED_ISO")
    xml_path=$(get_vps_value "$vps_id" "XML_PATH")
    ci_dir="$CLOUDINIT_DIR/$hostname"

    if ! prompt_confirm "  Are you sure you want to delete VPS '$hostname'?"; then
        echo "  Cancelled."
        press_enter
        return
    fi

    echo "  Deleting VPS '$hostname'..."

    local state
    state=$(virsh domstate "$vm_name" 2>/dev/null)
    if [[ "$state" == "running" ]]; then
        virsh destroy "$vm_name" >/dev/null 2>&1
    fi

    virsh undefine "$vm_name" --nvram >/dev/null 2>&1

    remove_port_forward "$ssh_port" "$ip_addr"

    rm -f "$disk_path" 2>/dev/null
    rm -f "$seed_iso" 2>/dev/null
    rm -f "$xml_path" 2>/dev/null
    rm -rf "$ci_dir" 2>/dev/null

    local config_path
    config_path=$(get_vps_config_path "$vps_id")
    rm -f "$config_path" 2>/dev/null

    release_ip "$ip_addr"

    echo "  VPS '$hostname' deleted."
    log_msg "INFO" "Deleted VPS: $hostname (ID: $vps_id)"
    press_enter
}

vps_info() {
    echo ""
    echo "------------- VPS Information -------------"
    echo ""

    local ids
    ids=$(get_all_vps_ids)
    if [[ -z "$ids" ]]; then
        echo "  No VPS found."
        press_enter
        return
    fi

    draw_vps_table
    echo ""

    local vps_id
    vps_id=$(prompt "  Enter VPS ID: ")
    if ! validate_positive_int "$vps_id"; then
        echo "  ERROR: Invalid ID."
        press_enter
        return
    fi

    local err
    err=$(validate_vps_id_exists "$vps_id")
    if [[ -n "$err" ]]; then
        echo "  $err"
        press_enter
        return
    fi

    local vm_name hostname username ram disk cpu ssh_port os mac ip_addr disk_path
    vm_name=$(get_vps_value "$vps_id" "VM_NAME")
    hostname=$(get_vps_value "$vps_id" "HOSTNAME")
    username=$(get_vps_value "$vps_id" "USERNAME")
    ram=$(get_vps_value "$vps_id" "RAM")
    disk=$(get_vps_value "$vps_id" "DISK")
    cpu=$(get_vps_value "$vps_id" "CPU")
    ssh_port=$(get_vps_value "$vps_id" "SSH_PORT")
    os=$(get_vps_value "$vps_id" "OS")
    mac=$(get_vps_value "$vps_id" "MAC")
    ip_addr=$(get_vps_value "$vps_id" "IP_ADDR")
    disk_path=$(get_vps_value "$vps_id" "DISK_PATH")

    local state
    state=$(virsh domstate "$vm_name" 2>/dev/null || echo "undefined")

    local uptime="N/A"
    if [[ "$state" == "running" ]]; then
        local start_str
        start_str=$(virsh dominfo "$vm_name" 2>/dev/null | grep "^Started:" | sed 's/^Started:[[:space:]]*//')
        if [[ -n "$start_str" ]]; then
            local start_epoch now_epoch diff
            start_epoch=$(date -d "$start_str" +%s 2>/dev/null)
            now_epoch=$(date +%s)
            if [[ -n "$start_epoch" ]]; then
                diff=$((now_epoch - start_epoch))
                local days=$((diff / 86400))
                local hours=$(( (diff % 86400) / 3600 ))
                local minutes=$(( (diff % 3600) / 60 ))
                if (( days > 0 )); then
                    uptime="${days}d ${hours}h ${minutes}m"
                elif (( hours > 0 )); then
                    uptime="${hours}h ${minutes}m"
                else
                    uptime="${minutes}m"
                fi
            fi
        fi
    fi

    local disk_usage="N/A"
    if [[ -f "$disk_path" ]]; then
        local qemu_info
        qemu_info=$(qemu-img info "$disk_path" 2>/dev/null)
        local actual_size virtual_size
        actual_size=$(echo "$qemu_info" | grep "disk size:" | awk '{print $3}')
        virtual_size=$(echo "$qemu_info" | grep "virtual size:" | sed 's/.*(\(.*\))/\1/')
        if [[ -n "$actual_size" && -n "$virtual_size" ]]; then
            disk_usage="${actual_size} / ${virtual_size}"
        elif [[ -n "$actual_size" ]]; then
            disk_usage="${actual_size} used"
        fi
    fi

    echo ""
    draw_separator
    printf "  %-14s %s\n" "ID:"           "$vps_id"
    printf "  %-14s %s\n" "Hostname:"     "$hostname"
    printf "  %-14s %s\n" "Username:"     "$username"
    printf "  %-14s %s\n" "Status:"       "$state"
    printf "  %-14s %s\n" "CPU:"          "$cpu core(s)"
    printf "  %-14s %s\n" "RAM:"          "$ram MB"
    printf "  %-14s %s\n" "Disk:"         "$disk GB"
    printf "  %-14s %s\n" "Disk Usage:"   "$disk_usage"
    printf "  %-14s %s\n" "MAC Address:"  "$mac"
    printf "  %-14s %s\n" "IP Address:"   "$ip_addr"
    printf "  %-14s %s\n" "SSH Port:"     "$ssh_port"
    printf "  %-14s %s\n" "OS:"           "$os"
    printf "  %-14s %s\n" "Uptime:"       "$uptime"
    draw_separator
    echo ""
    press_enter
}