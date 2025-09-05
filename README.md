# zabbix-libvirt

This template set is designed for the deployment of libvirtd based KVM monitoring.

    The template "Libvirt KVM" should be linked to the host where the VM are deployed.
    The template "Libvirt KVM Guest" is used in discovery and normally should not be manually linked to a host.

Inspired in the current Zabbix VMware templates, uses virsh command to get status and statistics of hypervisor. Both system and user virtual machines are identified in the host and a new host is created by the discovery rule. This zabbix host represent a virtual machine and the template "Libvirt KVM Guest" is linked automaticaly to this host.

Tested on:

* RHEL 10.0
* Zabbix 7.4.x

## Authors

* Vicente Salvador

## Installation

### On monitored server (where you have kvm/libvirt)

* install and configure zabbix-agent
    ```sh
    dnf install zabbix-agent
    ```

* install required dependencies for shell commands
   ```sh
   dnf install jq awk 
   ```

* copy the file "userparameter-libvirt-hv.conf" into your zabbix include folder:
    ```sh
    cp configs/userparameter-libvirt-hv.conf /etc/zabbix/zabbix_agentd.d
    ```

* copy the support shell scripts to the zabbix folder:
    ```sh
    cp scripts/*.sh /etc/zabbix
    ```

* zabbix agent runs as unprivileged zabbis user. Allows sudo this user the virsh command. Create file at /etc/sudoers.d/zabbix:
    ```sh
    cat >/etc/sudoers.d/zabbix <EOF
    Defaults:zabbix !requiretty
    Defaults:zabbix !syslog
    zabbix ALL=(ALL) NOPASSWD: /usr/bin/virsh
    EOF
    ```

* reboot zabbix-agent service
    ```sh
    systemctl restart zabbix-agent
    ```

### On zabbix server

* import templates (xml file)

# Template Libvirt KVM

1. Create a new host to contact zabbix agent on KVM hypervisor
2. Link the template to the host created earlier

## Macros used

|Name|Description|Default|
|----|-----------|----|
|{$LIBVIRT.POOL.SPACE.PFREE.CRIT}|The critical threshold of the disk pool non allocated space. |10 |
|{$LIBVIRT.POOL.SPACE.PFREE.WARN}|The warning threshold of the disk pool non allocated space. |20 |
|{$LIBVIRT.VM.AUTOSTART}|Possibility to filter out VMs by autostart property. |enable\|disable |
|{$LIBVIRT.VM.PERSISTENT}|Possibility to filter out VMs persistent or not persistent |yes\|no |

## Items

|Name|Description|Type|Key and additional info|
|----|-----------|----|----|
|Hypervisor ping|<p>Hypervisor ping.</p>|`Simple check`|icmpping[]<p>Update: 2m</p>|
|Hypervisor number of guest VMs|<p>Number of guest virtual machines.</p>|`Zabbix agent`|libvirt.hv[vmnum]|
|Hypervisor CPU cores|<p>Number of physical CPU cores on the host. Physical CPU cores are the processors contained by a CPU package.</p>|`Calculated`|libvirt.hv.hw.cpu.num|
|Hypervisor CPU threads per core|<p>Number of threads of each physical CPU on the host.</p>|`Dependent`|libvirt.hv.cpu.threads|
|Hypervisor CPU threads|<p>Number of physical CPU threads on the host.</p>|`Dependent`|libvirt.hv.cpu.vnum|
|Hypervisor CPU Idle Time|<p> </p>|`Dependent`|libvirt.hv.cpu.idle|
|Hypervisor CPU IO Wait Time|<p> </p>|`Dependent`|libvirt.hv.cpu.iowait|
|Hypervisor CPU IO Wait in percent|<p> </p>|`Calculated`|libvirt.hv.cpu.iowait.perf|
|Hypervisor CPU System Time|<p> </p>|`Dependent`|libvirt.hv.cpu.system|
|Hypervisor CPU User Time|<p> </p>|`Dependent`|libvirt.hv.cpu.user|
|Hypervisor CPU Usage in percent|<p> </p>|`Calculated`|libvirt.hv.cpu.usage.perf|
|Hypervisor CPU current frequency|<p>The speed of the CPU cores. This is an average value if there are multiple speeds. The product of CPU frequency and number of cores is approximately equal to the sum of the MHz for all the individual cores on the host.</p>|`Dependent`|libvirt.hv.hw.cpu.freq|
|Hpervisor CPU model|<p>The CPU model.</p>|`Dependent`|libvirt.hv.hw.cpu.model|
|Hypervisor KSM % Merged pages|<p> </p>|`Calculated`|libvirt.hv.hw.ksm.merged.perf|
|Hypervisor KSM general profit|<p> </p>|`Dependent`|libvirt.hv.hw.ksm.profit|
|Hypervisor KSM shared memory|<p> </p>|`Dependent`|libvirt.hv.hw.ksm.shared|
|Hypervisor KSM sharing memory|<p> </p>|`Dependent`|libvirt.hv.hw.ksm.sharing|
|Hypervisor KSM eficiency ratio of page sharing|<p> </p>|`Calculated`|libvirt.hv.hw.ksm.sharing.perf|
|Hypervisor KSM unshared memory|<p> </p>|`Dependent`|libvirt.hv.hw.ksm.unshared|
|Hypervisor KSM volatile memory|<p> </p>|`Dependent`|libvirt.hv.hw.ksm.volatile|
|Hypervisor memory total|<p> </p>|`Dependent`|libvirt.hv.hw.memory|
|Hypervisor Model|<p>The system model identification.</p>|`Dependent`|libvirt.hv.hw.model|
|Hypervisor Bios UUID|<p>The hardware BIOS identification.</p>|`Dependent`|libvirt.hv.hw.uuid|
|Hypervisor library|<p>QEMU library version</p>|`Dependent`|libvirt.hv.library|
|Hypervisor memory cached|<p> </p>|`Dependent`|libvirt.hv.memory.cached|
|Hypervisor memory free|<p>Physical free memory on the host.</p>|`Dependent`|libvirt.hv.memory.free|
|Hypervisor network: muticast packets|<p> </p>|`Dependent`|libvirt.hv.net.multicast|
|Hypervisor network: Bytes received|<p> </p>|`Dependent`|libvirt.hv.net.rx_bytes|
|Hypervisor network: Inbound packets discarded|<p> </p>|`Dependent`|libvirt.hv.net.rx_dropped|
|Hypervisor network: Inbound packets with errors|<p> </p>|`Dependent`|libvirt.hv.net.rx_errors|
|Hypervisor network: Inbound packets|<p> </p>|`Dependent`|libvirt.hv.net.rx_packets|
|Hypervisor network: Bytes sent|<p> </p>|`Dependent`|libvirt.hv.net.tx_bytes|
|Hypervisor network: Outbound packets discarded|<p> </p>|`Dependent`|libvirt.hv.net.tx_dropped|
|Hypervisor network: Outbound packets with errors|<p> </p>|`Dependent`|libvirt.hv.net.tx_errors|
|Hypervisor network: Outbound packets|<p> </p>|`Dependent`|libvirt.hv.net.tx_packets|
|Hypervisor version|<p> </p>|`Dependent`|libvirt.hv.version|
|Hypervisor Uptime|<p>System uptime.</p>|`Zabbix agent`|libvirt.hv[uptime]|
|Hypervisor number of guest VMs|<p> </p>|`Zabbix agent`|libvirt.hv[vmnum]|
|HV: Get KSM data|<p> </p>|`Zabbix agent`|libvirt.hv[ksm.get]|
|HV: Get network data|<p> </p>|`Zabbix agent`|libvirt.hv[net.stats.get]|
|HV: Get CPU data|<p> </p>|`Zabbix agent`|libvirt.hv[nodecpu.stats.get]|
|HV: Get node Info|<p> </p>|`Zabbix agent`|libvirt.hv[nodeinfo.get]|
|HV: Get memory data|<p> </p>|`Zabbix agent`|libvirt.hv[nodemem.stats.get]|
|HV: Get pool data|<p> </p>|`Zabbix agent`|libvirt.hv[pool.stats.get]|
|HV: Get system Info|<p> </p>|`Zabbix agent`|libvirt.hv[sysinfo.get]|
|HV: Get libvirt version data|<p> </p>|`Zabbix agent`|libvirt.hv[version.get]|

## Triggers

|Name|Description|Expression|Priority|
|----|-----------|----------|--------|
|Hypervisor has been restarted|<p>-</p>|<p>**Expression**: last(/LibVirt KVM/libvirt.hv[uptime])&lt;15m</p><p>**Recovery expression**: </p>|warning|
|Hypervisor is down|<p>-</p>|<p>**Expression**: last(/LibVirt KVM/icmpping[])=0</p><p>**Recovery expression**: </p>|average|

## Discovery rules

|Name|Description|Type|Key and additional info|
|----|-----------|----|----|
|Libvirt hypervisor discovery|<p>Discovery of all users with active VM in the host.</p>|`Zabbix agent`|libvirt.hv[discovery]<p>Update: 2h</p>|
|Libvirt Pool discovery|<p>Discovery of all disk pools defined in all hypervisors in the host.</p>|`Dependent`|libvirt.pool.discovery|
|Network device discovery|<p>Discovery of all network devices used by hypervisors in the host.</p>|`Dependent`|libvirt.net.if.discovery|
|Libvirt VM discovery|<p>Discovery of all virtual machines in the host.</p>|`Zabbix agent`|libvirt.hv[vm.discovery]<p>Update: 2h</p>|

# Template Libvirt KVM Guest

## Macros used

|Name|Description|Default|
|----|-----------|----|
|{$LIBVIRT.VM.FS.PFREE.MIN.CRIT}|Libvirt guest free space threshold for the warning trigger. |10 |
|{$LIBVIRT.VM.FS.PFREE.MIN.WARN}|Libvirt guest free space threshold for the critical trigger. |20 |
|{$LIBVIRT.VM.FS.TRIGGER.USED}|Libvirt guest used free space trigger. Set to "1"/"0" to enable or disable the trigger. |0 |

## Items

|Name|Description|Type|Key and additional info|
|----|-----------|----|----|
|Hypervisor ping|<p>Hypervisor ping.</p>|`Simple check`|icmpping[]<p>Update: 2m</p>|

<!---

## Template links

|Name|
|----|
| |

## Discovery rules

|Name|Description|Type|Key and additional info|
|----|-----------|----|----|
|Network device discovery|<p>Discovery of all network devices.</p>|`Simple check`|libvirt.vm.net.if.discovery[{$URL},{HOST.HOST}]<p>Update: 1h</p>|
|Disk device discovery|<p>Discovery of all disk devices.</p>|`Simple check`|libvirt.vm.vfs.dev.discovery[{$URL},{HOST.HOST}]<p>Update: 1h</p>|
|Mounted filesystem discovery|<p>Discovery of all guest file systems.</p>|`Simple check`|libvirt.vm.vfs.fs.discovery[{$URL},{HOST.HOST}]<p>Update: 1h</p>|

## Items collected


|Name|Description|Type|Key and additional info|
|----|-----------|----|----|
|Cluster name|<p>Cluster name of the guest VM.</p>|`Simple check`|libvirt.vm.cluster.name[{$URL},{HOST.HOST}]<p>Update: 1h</p>|
|Swapped memory|<p>The amount of guest physical memory swapped out to the VM's swap device by ESX.</p>|`Simple check`|libvirt.vm.memory.size.swapped[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Unshared storage space|<p>Total storage space, in bytes, occupied by the virtual machine across all datastores, that is not shared with any other virtual machine.</p>|`Simple check`|libvirt.vm.storage.unshared[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Uncommitted storage space|<p>Additional storage space, in bytes, potentially used by this virtual machine on all datastores.</p>|`Simple check`|libvirt.vm.storage.uncommitted[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Committed storage space|<p>Total storage space, in bytes, committed to this virtual machine across all datastores.</p>|`Simple check`|libvirt.vm.storage.committed[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Power state|<p>The current power state of the virtual machine.</p>|`Simple check`|libvirt.vm.powerstate[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Memory size|<p>Total size of configured memory.</p>|`Simple check`|vmware.vm.memory.size[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Host memory usage|<p>The amount of host physical memory allocated to the VM, accounting for saving from memory sharing with other VMs.</p>|`Simple check`|vmware.vm.memory.size.usage.host[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Guest memory usage|<p>The amount of guest physical memory that is being used by the VM.</p>|`Simple check`|vmware.vm.memory.size.usage.guest[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Shared memory|<p>The amount of guest physical memory shared through transparent page sharing.</p>|`Simple check`|vmware.vm.memory.size.shared[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Number of virtual CPUs|<p>Number of virtual CPUs assigned to the guest.</p>|`Simple check`|vmware.vm.cpu.num[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Private memory|<p>Amount of memory backed by host memory and not being shared.</p>|`Simple check`|vmware.vm.memory.size.private[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Compressed memory|<p>The amount of memory currently in the compression cache for this VM.</p>|`Simple check`|vmware.vm.memory.size.compressed[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Ballooned memory|<p>The amount of guest physical memory that is currently reclaimed through the balloon driver.</p>|`Simple check`|vmware.vm.memory.size.ballooned[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Hypervisor name|<p>Hypervisor name of the guest VM.</p>|`Simple check`|libvirt.vm.hv.name[{$URL},{HOST.HOST}]<p>Update: 1h</p>|
|Datacenter name|<p>Datacenter name of the guest VM.</p>|`Simple check`|libvirt.vm.datacenter.name[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|CPU usage|<p>Current upper-bound on CPU usage. The upper-bound is based on the host the virtual machine is current running on, as well as limits configured on the virtual machine itself or any parent resource pool. Valid while the virtual machine is running.</p>|`Simple check`|libvirt.vm.cpu.usage[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|CPU ready|<p>Time that the virtual machine was ready, but could not get scheduled to run on the physical CPU during last measurement interval (libvirt vCenter/ESXi Server performance counter sampling interval - 20 seconds)</p>|`Simple check`|libvirt.vm.cpu.ready[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Uptime|<p>System uptime.</p>|`Simple check`|libvirt.vm.uptime[{$URL},{HOST.HOST}]<p>Update: 1m</p>|
|Number of bytes received on interface {#IFDESC}|<p>-</p>|`Simple check`|libvirt.vm.net.if.in[{$URL},{HOST.HOST},{#IFNAME},bps]<p>Update: 1m</p><p>LLD</p>|
|Number of packets received on interface {#IFDESC}|<p>-</p>|`Simple check`|libvirt.vm.net.if.in[{$URL},{HOST.HOST},{#IFNAME},pps]<p>Update: 1m</p><p>LLD</p>|
|Number of bytes transmitted on interface {#IFDESC}|<p>-</p>|`Simple check`|libvirt.vm.net.if.out[{$URL},{HOST.HOST},{#IFNAME},bps]<p>Update: 1m</p><p>LLD</p>|
|Number of packets transmitted on interface {#IFDESC}|<p>-</p>|`Simple check`|libvirt.vm.net.if.out[{$URL},{HOST.HOST},{#IFNAME},pps]<p>Update: 1m</p><p>LLD</p>|
|Average number of bytes read from the disk {#DISKDESC}|<p>-</p>|`Simple check`|libvirt.vm.vfs.dev.read[{$URL},{HOST.HOST},{#DISKNAME},bps]<p>Update: 1m</p><p>LLD</p>|
|Average number of reads from the disk {#DISKDESC}|<p>-</p>|`Simple check`|libvirt.vm.vfs.dev.read[{$URL},{HOST.HOST},{#DISKNAME},ops]<p>Update: 1m</p><p>LLD</p>|
|Average number of bytes written to the disk {#DISKDESC}|<p>-</p>|`Simple check`|libvirt.vm.vfs.dev.write[{$URL},{HOST.HOST},{#DISKNAME},bps]<p>Update: 1m</p><p>LLD</p>|
|Average number of writes to the disk {#DISKDESC}|<p>-</p>|`Simple check`|libvirt.vm.vfs.dev.write[{$URL},{HOST.HOST},{#DISKNAME},ops]<p>Update: 1m</p><p>LLD</p>|
|Free disk space on {#FSNAME}|<p>-</p>|`Simple check`|libvirt.vm.vfs.fs.size[{$URL},{HOST.HOST},{#FSNAME},free]<p>Update: 1m</p><p>LLD</p>|
|Free disk space on {#FSNAME} (percentage)|<p>-</p>|`Simple check`|libvirt.vm.vfs.fs.size[{$URL},{HOST.HOST},{#FSNAME},pfree]<p>Update: 1m</p><p>LLD</p>|
|Total disk space on {#FSNAME}|<p>-</p>|`Simple check`|libvirt.vm.vfs.fs.size[{$URL},{HOST.HOST},{#FSNAME},total]<p>Update: 1h</p><p>LLD</p>|
|Used disk space on {#FSNAME}|<p>-</p>|`Simple check`|libvirt.vm.vfs.fs.size[{$URL},{HOST.HOST},{#FSNAME},used]<p>Update: 1m</p><p>LLD</p>|

## Triggers

-->