# CodingBoz

Terminal-based VPS management platform for KVM/QEMU on Linux.

## Requirements

- Ubuntu 20.04+ or Debian 11+
- KVM support (hardware virtualization)
- Root access

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Amir565-ux/CodingBoz/main/install.sh)
```

## Usage

```bash
codingboz
```

## Features

- Create, start, stop, restart, delete KVM virtual machines
- Cloud-init provisioning with static networking
- Automatic SSH port forwarding
- Serial console access
- VPS information dashboard
- Input validation and duplicate prevention

## Supported Operating Systems

- Ubuntu 22.04 (Jammy)
- Ubuntu 24.04 (Noble)
- Debian 12 (Bookworm)
- CentOS Stream 9
- AlmaLinux 9

## Project Structure

```
/opt/codingboz/          - Main installation
/etc/codingboz/          - Runtime configuration
/var/lib/codingboz/      - Disks, images, cloud-init
/var/log/codingboz/      - Logs
```

## Uninstall

```bash
rm -rf /opt/codingboz /etc/codingboz /var/lib/codingboz /var/log/codingboz /usr/local/bin/codingboz /etc/systemd/system/codingboz.service
systemctl daemon-reload
```

## License

MIT