#!/bin/bash

generate_cloud_init() {
    local vps_id="$1"
    local hostname="$2"
    local username="$3"
    local password="$4"
    local ip_addr="$5"

    local ci_dir="$CLOUDINIT_DIR/${hostname}"
    mkdir -p "$ci_dir"

    local user_data_tpl="$TEMPLATE_DIR/user-data.tpl"
    local meta_data_tpl="$TEMPLATE_DIR/meta-data.tpl"

    local user_block=""
    if [[ -n "$username" && "$username" != "root" ]]; then
        user_block=$(cat <<USEREOF
users:
  - name: ${username}
    plain_text_passwd: ${password}
    lock_passwd: false
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
USEREOF
        )
    fi

    local network_block=$(cat <<NETEOF
network:
  version: 2
  ethernets:
    id0:
      match:
        name: "en*"
      addresses:
        - ${ip_addr}/${NETWORK_PREFIX}
      gateway4: ${NETWORK_GATEWAY}
      nameservers:
        addresses: [${NETWORK_DNS1}, ${NETWORK_DNS2}]
NETEOF
    )

    sed -e "s|__HOSTNAME__|${hostname}|g" \
        -e "s|__PASSWORD__|${password}|g" \
        -e "s|__USERS_BLOCK__|${user_block}|g" \
        -e "s|__NETWORK_BLOCK__|${network_block}|g" \
        "$user_data_tpl" > "$ci_dir/user-data"

    sed -e "s|__HOSTNAME__|${hostname}|g" \
        "$meta_data_tpl" > "$ci_dir/meta-data"

    local iso_path="$CLOUDINIT_DIR/${hostname}-seed.iso"

    if command -v genisoimage &>/dev/null; then
        genisoimage -output "$iso_path" -volid cidata -joliet -rock "$ci_dir/user-data" "$ci_dir/meta-data" 2>/dev/null
    elif command -v mkisofs &>/dev/null; then
        mkisofs -output "$iso_path" -volid cidata -joliet -rock "$ci_dir/user-data" "$ci_dir/meta-data" 2>/dev/null
    elif command -v xorriso &>/dev/null; then
        xorriso -as genisoimage -output "$iso_path" -volid cidata -joliet -rock "$ci_dir/user-data" "$ci_dir/meta-data" 2>/dev/null
    else
        echo "ERROR: No ISO generation tool found (genisoimage, mkisofs, xorriso)." >&2
        return 1
    fi

    if [[ ! -f "$iso_path" ]]; then
        echo "ERROR: Failed to create cloud-init ISO." >&2
        return 1
    fi

    log_msg "INFO" "Generated cloud-init ISO: $iso_path"
    echo "$iso_path"
}