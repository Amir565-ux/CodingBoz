#!/bin/bash

generate_vm_xml() {
    local vm_name="$1"
    local ram_mb="$2"
    local cpu_cores="$3"
    local disk_path="$4"
    local seed_iso="$5"
    local mac_addr="$6"

    local xml
    xml=$(cat <<XMLEOF
<domain type='kvm'>
  <name>${vm_name}</name>
  <memory unit='MiB'>${ram_mb}</memory>
  <vcpu placement='static'>${cpu_cores}</vcpu>
  <os>
    <type arch='x86_64' machine='pc'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-model' check='partial'/>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' discard='unmap'/>
      <source file='${disk_path}'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='${seed_iso}'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>
    <interface type='network'>
      <mac address='${mac_addr}'/>
      <source network='${NETWORK_NAME}'/>
      <model type='virtio'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <channel type='unix'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
    </channel>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>
      <listen type='address' address='127.0.0.1'/>
    </graphics>
    <video>
      <model type='virtio' heads='1' primary='yes'/>
    </video>
    <memballoon model='virtio'/>
  </devices>
</domain>
XMLEOF
    )

    local xml_path="$CONF_DIR/${vm_name}.xml"
    echo "$xml" > "$xml_path"
    log_msg "INFO" "Generated VM XML: $xml_path"
    echo "$xml_path"
}