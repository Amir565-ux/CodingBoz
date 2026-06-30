#!/bin/bash

validate_hostname() {
    local hostname="$1"
    if [[ -z "$hostname" ]]; then
        echo "ERROR: Hostname cannot be empty."
        return 1
    fi
    if [[ ${#hostname} -gt 63 ]]; then
        echo "ERROR: Hostname must be 63 characters or less."
        return 1
    fi
    if ! [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]{0,61}[a-zA-Z0-9])?$ ]]; then
        echo "ERROR: Invalid hostname. Use only letters, numbers, hyphens, and dots."
        return 1
    fi
    return 0
}

validate_username() {
    local username="$1"
    if [[ -z "$username" ]]; then
        echo "ERROR: Username cannot be empty."
        return 1
    fi
    if ! [[ "$username" =~ ^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$ ]]; then
        echo "ERROR: Invalid username. Start with a letter or underscore, use letters, numbers, hyphens, underscores."
        return 1
    fi
    return 0
}

validate_password() {
    local password="$1"
    if [[ -z "$password" ]]; then
        echo "ERROR: Password cannot be empty."
        return 1
    fi
    if [[ ${#password} -lt 4 ]]; then
        echo "ERROR: Password must be at least 4 characters."
        return 1
    fi
    return 0
}

validate_ram() {
    local ram="$1"
    if ! [[ "$ram" =~ ^[0-9]+$ ]]; then
        echo "ERROR: RAM must be a number."
        return 1
    fi
    if (( ram < 128 )); then
        echo "ERROR: RAM must be at least 128 MB."
        return 1
    fi
    if (( ram > 1048576 )); then
        echo "ERROR: RAM cannot exceed 1048576 MB (1 TB)."
        return 1
    fi
    return 0
}

validate_cpu() {
    local cpu="$1"
    if ! [[ "$cpu" =~ ^[0-9]+$ ]]; then
        echo "ERROR: CPU cores must be a number."
        return 1
    fi
    if (( cpu < 1 )); then
        echo "ERROR: CPU cores must be at least 1."
        return 1
    fi
    local host_cpus
    host_cpus=$(nproc)
    if (( cpu > host_cpus )); then
        echo "ERROR: CPU cores cannot exceed host CPUs ($host_cpus)."
        return 1
    fi
    return 0
}

validate_disk() {
    local disk="$1"
    if ! [[ "$disk" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Disk size must be a number."
        return 1
    fi
    if (( disk < 1 )); then
        echo "ERROR: Disk size must be at least 1 GB."
        return 1
    fi
    if (( disk > 10000 )); then
        echo "ERROR: Disk size cannot exceed 10000 GB."
        return 1
    fi
    return 0
}

validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "ERROR: SSH port must be a number."
        return 1
    fi
    if (( port < 1 || port > 65535 )); then
        echo "ERROR: SSH port must be between 1 and 65535."
        return 1
    fi
    return 0
}

validate_vps_id_exists() {
    local id="$1"
    local config_path
    config_path=$(get_vps_config_path "$id")
    if [[ ! -f "$config_path" ]]; then
        echo "ERROR: VPS with ID $id does not exist."
        return 1
    fi
    return 0
}

check_duplicate_hostname() {
    local hostname="$1"
    local exclude_id="${2:-}"
    local ids
    ids=$(get_all_vps_ids)
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        [[ "$id" == "$exclude_id" ]] && continue
        local existing
        existing=$(get_vps_value "$id" "HOSTNAME")
        if [[ "$existing" == "$hostname" ]]; then
            echo "ERROR: A VPS with hostname '$hostname' already exists (ID: $id)."
            return 1
        fi
    done <<< "$ids"
    return 0
}

check_duplicate_port() {
    local port="$1"
    local exclude_id="${2:-}"
    local ids
    ids=$(get_all_vps_ids)
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        [[ "$id" == "$exclude_id" ]] && continue
        local existing
        existing=$(get_vps_value "$id" "SSH_PORT")
        if [[ "$existing" == "$port" ]]; then
            echo "ERROR: SSH port $port is already in use by VPS ID $id."
            return 1
        fi
    done <<< "$ids"
    return 0
}

validate_positive_int() {
    local val="$1"
    [[ "$val" =~ ^[0-9]+$ ]] && (( val > 0 ))
}