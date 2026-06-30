#!/bin/bash

generate_mac() {
    local mac
    local existing_macs
    existing_macs=$(virsh net-dumpxml "$NETWORK_NAME" 2>/dev/null | grep -oP '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' || true)
    local attempts=0
    while (( attempts < 100 )); do
        mac=$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
        if ! echo "$existing_macs" | grep -qi "$mac"; then
            echo "$mac"
            return 0
        fi
        ((attempts++))
    done
    echo "52:54:00:aa:bb:cc"
}

ip_to_int() {
    local a b c d
    IFS='.' read -r a b c d <<< "$1"
    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

int_to_ip() {
    local ip="$1"
    echo "$(( (ip >> 24) & 255 )).$(( (ip >> 16) & 255 )).$(( (ip >> 8) & 255 )).$(( ip & 255 ))"
}

allocate_ip() {
    local start_int end_int
    start_int=$(ip_to_int "$NETWORK_IP_START")
    end_int=$(ip_to_int "$NETWORK_IP_END")

    local used_ips=""
    if [[ -f "$IP_POOL_FILE" ]]; then
        used_ips=$(grep -v '^\s*$' "$IP_POOL_FILE" 2>/dev/null || true)
    fi

    local ip_int=$start_int
    while (( ip_int <= end_int )); do
        local ip
        ip=$(int_to_ip "$ip_int")
        if ! echo "$used_ips" | grep -qx "$ip"; then
            echo "$ip" >> "$IP_POOL_FILE"
            echo "$ip"
            return 0
        fi
        ((ip_int++))
    done

    echo "ERROR: No IP addresses available in pool ($NETWORK_IP_START - $NETWORK_IP_END)." >&2
    return 1
}

release_ip() {
    local ip="$1"
    if [[ -f "$IP_POOL_FILE" ]]; then
        local tmp
        tmp=$(mktemp)
        grep -vx "$ip" "$IP_POOL_FILE" > "$tmp" 2>/dev/null || true
        mv "$tmp" "$IP_POOL_FILE"
    fi
}

add_port_forward() {
    local host_port="$1"
    local vm_ip="$2"
    local vm_port="${3:-22}"

    iptables -t nat -A PREROUTING -p tcp --dport "$host_port" -j DNAT --to-destination "${vm_ip}:${vm_port}" 2>/dev/null
    iptables -t nat -A POSTROUTING -p tcp -d "$vm_ip" --dport "$vm_port" -j MASQUERADE 2>/dev/null
    log_msg "INFO" "Added port forward: $host_port -> ${vm_ip}:${vm_port}"
}

remove_port_forward() {
    local host_port="$1"
    local vm_ip="$2"
    local vm_port="${3:-22}"

    iptables -t nat -D PREROUTING -p tcp --dport "$host_port" -j DNAT --to-destination "${vm_ip}:${vm_port}" 2>/dev/null
    iptables -t nat -D POSTROUTING -p tcp -d "$vm_ip" --dport "$vm_port" -j MASQUERADE 2>/dev/null
    log_msg "INFO" "Removed port forward: $host_port -> ${vm_ip}:${vm_port}"
}

restore_all_port_forwards() {
    local ids
    ids=$(get_all_vps_ids)
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        local ssh_port vm_ip
        ssh_port=$(get_vps_value "$id" "SSH_PORT")
        vm_ip=$(get_vps_value "$id" "IP_ADDR")
        if [[ -n "$ssh_port" && -n "$vm_ip" ]]; then
            add_port_forward "$ssh_port" "$vm_ip"
        fi
    done <<< "$ids"
    log_msg "INFO" "Restored all port forwarding rules."
}

ensure_network() {
    if virsh net-info "$NETWORK_NAME" &>/dev/null; then
        if [[ "$(virsh net-info "$NETWORK_NAME" 2>/dev/null | grep "^Active:" | awk '{print $2}')" != "yes" ]]; then
            virsh net-start "$NETWORK_NAME" 2>/dev/null
        fi
        return 0
    fi

    local xml
    xml=$(cat <<NETEOF
<network>
  <name>${NETWORK_NAME}</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='${NETWORK_BRIDGE}' stp='on' delay='0'/>
  <ip address='${NETWORK_GATEWAY}' netmask='${NETWORK_NETMASK}'>
    <dhcp>
      <range start='10.10.10.2' end='10.10.10.99'/>
    </dhcp>
  </ip>
</network>
NETEOF
    )

    local tmp_net
    tmp_net=$(mktemp)
    echo "$xml" > "$tmp_net"
    virsh net-define "$tmp_net" 2>/dev/null
    rm -f "$tmp_net"
    virsh net-start "$NETWORK_NAME" 2>/dev/null
    virsh net-autostart "$NETWORK_NAME" 2>/dev/null
    log_msg "INFO" "Created and started network: $NETWORK_NAME"
}