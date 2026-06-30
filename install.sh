#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This installer must be run as root."
    exit 1
fi

echo "=========================================="
echo "         CodingBoz Installer"
echo "=========================================="
echo ""

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
    else
        echo "ERROR: Cannot detect operating system."
        exit 1
    fi
}

check_kvm() {
    if ! grep -qE 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
        echo "Your VPS doesn't support KVM/QEMU virtualization."
        exit 1
    fi
    if [[ ! -e /dev/kvm ]]; then
        echo "Your VPS doesn't support KVM/QEMU virtualization."
        exit 1
    fi
    echo "[OK] KVM support detected."
}

install_packages() {
    echo "[*] Updating package lists..."
    case "$OS_ID" in
        ubuntu|debian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            echo "[*] Installing packages..."
            apt-get install -y -qq \
                qemu-kvm \
                libvirt-daemon-system \
                libvirt-clients \
                bridge-utils \
                cloud-init \
                curl \
                wget \
                git \
                sudo \
                openssl \
                virtinst \
                genisoimage \
                iptables \
                jq \
                > /dev/null 2>&1
            ;;
        *)
            echo "ERROR: Unsupported OS: $OS_ID"
            exit 1
            ;;
    esac
    echo "[OK] Packages installed."
}

enable_services() {
    echo "[*] Enabling services..."
    systemctl enable libvirtd >/dev/null 2>&1
    systemctl start libvirtd >/dev/null 2>&1
    systemctl enable virtnetworkd >/dev/null 2>&1 || true
    systemctl start virtnetworkd >/dev/null 2>&1 || true
    echo "[OK] Services enabled."
}

install_files() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    echo "[*] Installing CodingBoz to /opt/codingboz..."
    mkdir -p /opt/codingboz
    cp -r "$script_dir/lib" /opt/codingboz/
    cp -r "$script_dir/templates" /opt/codingboz/
    chmod -R 755 /opt/codingboz/lib
    chmod -R 755 /opt/codingboz/templates

    echo "[*] Installing main script..."
    cp "$script_dir/codingboz" /opt/codingboz/codingboz
    chmod 755 /opt/codingboz/codingboz

    echo "[*] Creating symlink..."
    ln -sf /opt/codingboz/codingboz /usr/local/bin/codingboz

    echo "[*] Setting up configuration..."
    mkdir -p /etc/codingboz/vps
    if [[ ! -f /etc/codingboz/codingboz.conf ]]; then
        cp "$script_dir/config/codingboz.conf" /etc/codingboz/codingboz.conf
    fi

    echo "[*] Creating data directories..."
    mkdir -p /var/lib/codingboz/disks
    mkdir -p /var/lib/codingboz/images
    mkdir -p /var/lib/codingboz/cloud-init
    mkdir -p /var/log/codingboz
    touch /var/log/codingboz/codingboz.log
    touch /etc/codingboz/ip_pool
    echo "1" > /etc/codingboz/next_id

    echo "[*] Installing systemd service..."
    cp "$script_dir/systemd/codingboz.service" /etc/systemd/system/codingboz.service
    systemctl daemon-reload
    systemctl enable codingboz.service >/dev/null 2>&1

    echo "[OK] Files installed."
}

create_default_network() {
    echo "[*] Setting up CodingBoz network..."
    if virsh net-info codingboz &>/dev/null; then
        echo "[OK] Network already exists."
        return
    fi

    local xml
    xml=$(cat <<'NETEOF'
<network>
  <name>codingboz</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='cbr0' stp='on' delay='0'/>
  <ip address='10.10.10.1' netmask='255.255.255.0'>
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
    virsh net-define "$tmp_net" >/dev/null 2>&1
    rm -f "$tmp_net"
    virsh net-start codingboz >/dev/null 2>&1
    virsh net-autostart codingboz >/dev/null 2>&1
    echo "[OK] Network created."
}

setup_iptables() {
    echo "[*] Configuring iptables for NAT..."
    if ! iptables -t nat -C POSTROUTING -s 10.10.10.0/24 ! -d 10.10.10.0/24 -j MASQUERADE 2>/dev/null; then
        iptables -t nat -A POSTROUTING -s 10.10.10.0/24 ! -d 10.10.10.0/24 -j MASQUERADE 2>/dev/null
    fi
    echo "[OK] iptables configured."
}

finalize() {
    echo ""
    echo "=========================================="
    echo "     CodingBoz installed successfully!"
    echo "=========================================="
    echo ""
    echo "  Run 'codingboz' to start."
    echo ""
}

detect_os
echo "[OK] Detected: $OS_ID $OS_VERSION"
check_kvm
install_packages
enable_services
install_files
create_default_network
setup_iptables
finalize