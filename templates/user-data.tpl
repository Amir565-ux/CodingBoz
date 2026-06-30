#cloud-config
hostname: __HOSTNAME__
manage_etc_hosts: true
ssh_pwauth: true
chpasswd:
  expire: false
  list: |
    root:__PASSWORD__
__USERS_BLOCK__
__NETWORK_BLOCK__
runcmd:
  - systemctl enable serial-getty@ttyS0.service
  - systemctl start serial-getty@ttyS0.service