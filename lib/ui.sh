#!/bin/bash

clear_screen() {
    clear
}

draw_header() {
    echo "=================================================="
    echo ""
    echo "                 CodingBoz"
    echo ""
    echo "=================================================="
    echo ""
}

draw_main_menu() {
    clear_screen
    draw_header
    echo "=============== MAIN MENU ==============="
    echo ""
    echo "[1] VPS"
    echo "[0] Exit"
    echo ""
}

draw_vps_menu() {
    clear_screen
    draw_header
    echo "================== VPS =================="
    echo ""
    draw_vps_table
    echo ""
    echo "[1] Create VPS"
    echo "[2] Start VPS"
    echo "[3] Stop VPS"
    echo "[4] Restart VPS"
    echo "[5] Delete VPS"
    echo "[6] VPS Information"
    echo "[7] Refresh List"
    echo "[0] Back"
    echo ""
}

draw_vps_table() {
    local ids
    ids=$(get_all_vps_ids)

    if [[ -z "$ids" ]]; then
        echo "  No VPS found."
        return
    fi

    local -a col_id=() col_host=() col_status=() col_cpu=() col_ram=() col_disk=() col_port=()

    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        col_id+=("$id")
        col_host+=("$(get_vps_value "$id" "HOSTNAME")")
        local state
        state=$(virsh domstate "${VPS_PREFIX}$(get_vps_value "$id" "HOSTNAME")" 2>/dev/null || echo "unknown")
        col_status+=("$state")
        col_cpu+=("$(get_vps_value "$id" "CPU")")
        col_ram+=("$(get_vps_value "$id" "RAM") MB")
        col_disk+=("$(get_vps_value "$id" "DISK") GB")
        col_port+=("$(get_vps_value "$id" "SSH_PORT")")
    done <<< "$ids"

    local w_id=4 w_host=9 w_status=9 w_cpu=4 w_ram=8 w_disk=7 w_port=9

    for h in "${col_host[@]}"; do (( ${#h} > w_host )) && w_host=${#h}; done
    for s in "${col_status[@]}"; do (( ${#s} > w_status )) && w_status=${#s}; done
    for p in "${col_port[@]}"; do (( ${#p} > w_port )) && w_port=${#p}; done

    w_host=$((w_host + 2))
    w_status=$((w_status + 2))

    local hdr_id="ID" hdr_host="HOSTNAME" hdr_status="STATUS" hdr_cpu="CPU" hdr_ram="RAM" hdr_disk="DISK" hdr_port="SSH PORT"

    printf " %-${w_id}s %-${w_host}s %-${w_status}s %-${w_cpu}s %-${w_ram}s %-${w_disk}s %-${w_port}s\n" \
        "$hdr_id" "$hdr_host" "$hdr_status" "$hdr_cpu" "$hdr_ram" "$hdr_disk" "$hdr_port"

    local sep_id=$(printf '%.0s-' $(seq 1 $w_id))
    local sep_host=$(printf '%.0s-' $(seq 1 $w_host))
    local sep_status=$(printf '%.0s-' $(seq 1 $w_status))
    local sep_cpu=$(printf '%.0s-' $(seq 1 $w_cpu))
    local sep_ram=$(printf '%.0s-' $(seq 1 $w_ram))
    local sep_disk=$(printf '%.0s-' $(seq 1 $w_disk))
    local sep_port=$(printf '%.0s-' $(seq 1 $w_port))

    printf " %-${w_id}s %-${w_host}s %-${w_status}s %-${w_cpu}s %-${w_ram}s %-${w_disk}s %-${w_port}s\n" \
        "$sep_id" "$sep_host" "$sep_status" "$sep_cpu" "$sep_ram" "$sep_disk" "$sep_port"

    local i=0
    local count=${#col_id[@]}
    while (( i < count )); do
        printf " %-${w_id}s %-${w_host}s %-${w_status}s %-${w_cpu}s %-${w_ram}s %-${w_disk}s %-${w_port}s\n" \
            "${col_id[$i]}" "${col_host[$i]}" "${col_status[$i]}" "${col_cpu[$i]}" "${col_ram[$i]}" "${col_disk[$i]}" "${col_port[$i]}"
        ((i++))
    done
}

prompt() {
    local msg="$1"
    printf "%s" "$msg"
    read -r reply
    echo "$reply"
}

prompt_password() {
    local msg="$1"
    printf "%s" "$msg"
    read -rs reply
    echo ""
    echo "$reply"
}

prompt_confirm() {
    local msg="$1"
    local ans
    printf "%s (y/N): " "$msg"
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

press_enter() {
    printf "Press Enter to continue..."
    read -r
}

draw_separator() {
    echo "=================================================="
}