#!/bin/bash

CONF_FILE="/etc/codingboz/codingboz.conf"

if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
else
    echo "ERROR: Configuration file not found at $CONF_FILE" >&2
    echo "Run install.sh first." >&2
    exit 1
fi

REQUIRED_DIRS=(
    "$CONF_DIR"
    "$VPS_DIR"
    "$DISK_DIR"
    "$IMAGE_DIR"
    "$CLOUDINIT_DIR"
    "$LOG_DIR"
)

for d in "${REQUIRED_DIRS[@]}"; do
    mkdir -p "$d" 2>/dev/null
done

touch "$LOG_FILE" "$IP_POOL_FILE" "$NEXT_ID_FILE" 2>/dev/null

log_msg() {
    local level="$1"
    shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    echo "$msg" >> "$LOG_FILE"
    if [[ "$level" == "ERROR" ]]; then
        echo "$msg" >&2
    fi
}

get_next_id() {
    local id
    id=$(cat "$NEXT_ID_FILE" 2>/dev/null || echo "1")
    echo "$id"
}

increment_id() {
    local current
    current=$(get_next_id)
    echo $((current + 1)) > "$NEXT_ID_FILE"
}

get_vps_config_path() {
    local id="$1"
    echo "$VPS_DIR/$id.conf"
}

get_all_vps_ids() {
    local ids=()
    if [[ -d "$VPS_DIR" ]]; then
        for f in "$VPS_DIR"/*.conf; do
            [[ -f "$f" ]] || continue
            local basename
            basename=$(basename "$f" .conf)
            [[ "$basename" =~ ^[0-9]+$ ]] && ids+=("$basename")
        done
    fi
    printf '%s\n' "${ids[@]}" | sort -n
}

get_vps_value() {
    local id="$1"
    local key="$2"
    local config_path
    config_path=$(get_vps_config_path "$id")
    if [[ -f "$config_path" ]]; then
        grep "^${key}=" "$config_path" 2>/dev/null | head -1 | cut -d'=' -f2-
    fi
}

get_vms_matching_prefix() {
    virsh list --all --name 2>/dev/null | grep "^${VPS_PREFIX}" | sort
}

VPS_PREFIX="cb_"