# zabbix-libvirt

This template set is designed for the deployment of libvirtd based KVM monitoring.

* The template "Libvirt KVM" should be linked to the host where the VM are deployed.
* The template "Libvirt KVM Guest" is used in discovery and normally should not be manually linked to a host.

Inspired in the current Zabbix VMware templates, uses virsh command to get status and statistics of hypervisor. Both system and user virtual machines are identified in the host and a new host is created by the discovery rule. This zabbix host represent a virtual machine and the template "Libvirt KVM Guest" is linked automaticaly to this host.

Some information can be better obtained from Linux template, but we include some memory and CPU statistics here to be able to obtain
good dashboards without requiring external templates.

Tested on:

* RHEL 10.0
* Zabbix 7.4.x

## Authors

* Vicente Salvador Cubedo

### Contributors

* Jeff Slapp - Agent 2 documentation

## Installation

### On monitored server (where you have kvm/libvirt)

* install and configure zabbix-agent
    ```sh
    dnf install -y zabbix-agent
    ```
    or install zabbix agent 2 if you're using this new version:
    ```sh
    dnf install -y zabbix-agent2 zabbix-agent2-plugin-*
    ```

* install required dependencies for shell commands
   ```sh
   rpm -q jq      || dnf install jq
   rpm -q awk     || dnf install awk
   rpm -q grep    || dnf install grep
   rpm -q libxml2 || dnf install libxml2  # xmllint
   ```

* copy the file "userparameter-libvirt-hv.conf" into your zabbix agent include folder:
    ```sh
    cp configs/userparameter-libvirt-hv.conf /etc/zabbix/zabbix_agentd.d
    ```
    if you're using zabbix agent 2 place the config file into the plugins directory:
    ```sh
    cp configs/userparameter-libvirt-hv.conf /etc/zabbix/zabbix_agent2.d/plugins.d/
    ```

* copy the support shell scripts to the zabbix folder:
    ```sh
    cp scripts/*.sh /etc/zabbix
    chmod ug+x /etc/zabbix/*.sh
    ```

* zabbix agent runs as unprivileged user: zabbix. Allow this user to use sudo for the virsh command. Create file at /etc/sudoers.d/zabbix:
    ```sh
    cat >/etc/sudoers.d/zabbix <EOF
    Defaults:zabbix !requiretty
    Defaults:zabbix !syslog
    zabbix ALL=(ALL) NOPASSWD: /usr/bin/virsh
    EOF
    ```

* if domain OS is RHEL 9 or 10 (maybe applies to others), in the domain OS, edit /etc/sysconfig/qemu-ga and add guest-exec,guest-exec-status to the list of allowed rpcs in the FILTER_RPC_ARGS configuration parameter. This will allow to execute some items to get OS boottime. If security is a concern, do not change configuration and let this items fail.

* reboot zabbix-agent service
    ```sh
    systemctl restart zabbix-agent
    ```

### On zabbix server

* import templates (xml file)
* create a host and use Zabbix agent connection
* link libvirt KVM template to this hypervisor host

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
|Hypervisor CPU Idle Time|<p>Seconds the CPU spends completely idle, with no active tasks or pending I/O operations. Sums all cores time in this state.</p>|`Dependent`|libvirt.hv.cpu.idle|
|Hypervisor CPU IO Wait Time|<p>Seconds the CPU is idle but waiting for an input/output operation (like reading from or writing to a disk) to finish. Sums all cores time in this state.</p>|`Dependent`|libvirt.hv.cpu.iowait|
|Hypervisor CPU IO Wait in percent|<p> </p>|`Calculated`|libvirt.hv.cpu.iowait.perf|
|Hypervisor CPU System Time|<p>Seconds the CPU spends executing kernel-level tasks and system calls. Sums all cores time in this state.</p>|`Dependent`|libvirt.hv.cpu.system|
|Hypervisor CPU User Time|<p>Seconds the CPU spends running user-level applications and processes. Sums all cores time in this state.</p>|`Dependent`|libvirt.hv.cpu.user|
|Hypervisor CPU Usage in percent|<p>CPU user and system time in percent. 2 cores full working will get 200%.</p>|`Calculated`|libvirt.hv.cpu.usage.perf|
|Hypervisor CPU current frequency|<p>The speed of the CPU cores. This is an average value if there are multiple speeds. The product of CPU frequency and number of cores is approximately equal to the sum of the MHz for all the individual cores on the host.</p>|`Dependent`|libvirt.hv.hw.cpu.freq|
|Hpervisor CPU model|<p>The CPU model.</p>|`Dependent`|libvirt.hv.hw.cpu.model|
|Hypervisor KSM % Merged pages|<p> </p>|`Calculated`|libvirt.hv.hw.ksm.merged.perf|
|Hypervisor KSM general profit|<p> </p>|`Dependent`|libvirt.hv.hw.ksm.profit|
|Hypervisor KSM shared memory|<p>How many shared memory are being used.</p>|`Dependent`|libvirt.hv.hw.ksm.shared|
|Hypervisor KSM sharing memory|<p>How many more sites are sharing them i.e. how much saved</p>|`Dependent`|libvirt.hv.hw.ksm.sharing|
|Hypervisor KSM eficiency ratio of page sharing|<p> </p>|`Calculated`|libvirt.hv.hw.ksm.sharing.perf|
|Hypervisor KSM unshared memory|<p>How many memory unique but repeatedly checked for merging</p>|`Dependent`|libvirt.hv.hw.ksm.unshared|
|Hypervisor KSM volatile memory|<p>How many memory changing too fast to be placed in a tree</p>|`Dependent`|libvirt.hv.hw.ksm.volatile|
|Hypervisor memory total|<p>The physical memory size.</p>|`Dependent`|libvirt.hv.hw.memory|
|Hypervisor Model|<p>The system model identification.</p>|`Dependent`|libvirt.hv.hw.model|
|Hypervisor Bios UUID|<p>The hardware BIOS identification.</p>|`Dependent`|libvirt.hv.hw.uuid|
|Hypervisor library|<p>Libvirt hypervisor version</p>|`Dependent`|libvirt.hv.library|
|Hypervisor memory cached|<p> </p>|`Dependent`|libvirt.hv.memory.cached|
|Hypervisor memory free|<p>Physical free memory on the host.</p>|`Dependent`|libvirt.hv.memory.free|
|Hypervisor network: muticast packets|<p>Multicast packets sent by all network devices used as source by domains.</p>|`Dependent`|libvirt.hv.net.multicast|
|Hypervisor network: Bytes received|<p>Acumulated bytes received by all network devices used as source by domains.</p>|`Dependent`|libvirt.hv.net.rx_bytes|
|Hypervisor network: Inbound packets discarded|<p>Acumulated packets discarded when a device's reception buffers are full</p>|`Dependent`|libvirt.hv.net.rx_dropped|
|Hypervisor network: Inbound packets with errors|<p>Acumulated packets received with errors by all network devices used as source by domains.</p>|`Dependent`|libvirt.hv.net.rx_errors|
|Hypervisor network: Inbound packets|<p>Acumulated packets received by all network devices used as source by domains.</p>|`Dependent`|libvirt.hv.net.rx_packets|
|Hypervisor network: Bytes sent|<p>Acumulated bytes sent by all network devices used as source by domains.</p>|`Dependent`|libvirt.hv.net.tx_bytes|
|Hypervisor network: Outbound packets discarded|<p>Acumulated packets discarded when a device's transmission buffers are full.</p>|`Dependent`|libvirt.hv.net.tx_dropped|
|Hypervisor network: Outbound packets with errors|<p>Acumulated packets sent with errors by all network devices used as source by domains.</p>|`Dependent`|libvirt.hv.net.tx_errors|
|Hypervisor network: Outbound packets|<p>Acumulated packets sent by all network devices used as source by domains.</p>|`Dependent`|libvirt.hv.net.tx_packets|
|Hypervisor version|<p>The Running QEMU version.</p>|`Dependent`|libvirt.hv.version|
|Hypervisor Uptime|<p>System uptime.</p>|`Zabbix agent`|libvirt.hv[uptime]|
|Hypervisor number of guest VMs|<p>Total number of guest domains present in server.</p>|`Zabbix agent`|libvirt.hv[vmnum]|
|HV: Get KSM data|<p>Raw data getter</p>|`Zabbix agent`|libvirt.hv[ksm.get]|
|HV: Get network data|<p>Raw data getter</p>|`Zabbix agent`|libvirt.hv[net.stats.get]|
|HV: Get CPU data|<p>Raw data getter</p>|`Zabbix agent`|libvirt.hv[nodecpu.stats.get]|
|HV: Get node Info|<p>Raw data getter</p>|`Zabbix agent`|libvirt.hv[nodeinfo.get]|
|HV: Get memory data|<p>Raw data getter</p>|`Zabbix agent`|libvirt.hv[nodemem.stats.get]|
|HV: Get pool data|<p>Raw data getter</p>|`Zabbix agent`|libvirt.hv[pool.stats.get]|
|HV: Get system Info|<p>Raw data getter</p>|`Zabbix agent`|libvirt.hv[sysinfo.get]|
|HV: Get libvirt version data|<p>Raw data getter</p>|`Zabbix agent`|libvirt.hv[version.get]|

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
|VM CPU haltpoll fail time|<p>CPU halt polling fail time spent.</p>|`Dependent`|libvirt.vm.cpu.haltpoll.fail|
|VM CPU haltpoll success time|<p>CPU halt polling success time spent.</p>|`Dependent`|libvirt.vm.cpu.haltpoll.success|
|VM CPU system|<p>System cpu time spent.</p>|`Dependent`|libvirt.vm.cpu.system|
|VM CPU user|<p>User cpu time spent</p>|`Dependent`|libvirt.vm.cpu.user|
|VM CPU usage|<p>Total cpu time spent for this domain.</p>|`Dependent`|libvirt.vm.cpu.usage|
|VM CPU usage in percent|<p> </p>|`Calculated`|libvirt.vm.cpu.usage.perf|
|Guest balloon memory available|<p>The amount of usable memory as seen by the domain.</p>|`Dependent`|libvirt.vm.guest.memory.size.available|
|Guest balloon memory disk cache|<p>The amount of memory that can be reclaimed without additional I/O.</p>|`Dependent`|libvirt.vm.guest.memory.size.diskcache|
|Guest balloon memory swapped|<p>The amount of memory written out to swap space</p>|`Dependent`|libvirt.vm.guest.memory.size.swapped|
|Guest balloon memory unused|<p>The amount of memory left unused by the system.</p>|`Dependent`|libvirt.vm.guest.memory.size.unused|
|Guest balloon memory usable|<p>The amount of memory which can be reclaimed by balloon without causing host swapping</p>|`Dependent`|libvirt.vm.guest.memory.size.usable|
|Guest balloon memory current size|<p>The memory in KiB currently used.</p>|`Dependent`|libvirt.vm.guest.memory.current|
|Host balloon memory rss|<p>Resident Set Size of running domain's process.</p>|`Dependent`|libvirt.vm.memory.size.usage.host|
|VM Guest Tools status|<p>Monitoring of the QEMU Guest Agent operational status for this domain.</p>|`Zabbix agent`|libvirt.vm[tools, {$HV.USER},{$LIBVIRT.VM.UUID}]|
|Snapshot count|<p>Snapshot count of the guest VM.</p>|`Dependent`|libvirt.vm.snapshot.count|
|Snapshot latest date|<p>Latest snapshot date of the guest VM.</p>|`Dependent`|libvirt.vm.snapshot.latestdate|
|Snapshot oldest date|<p>Oldest snapshot date of the guest VM.</p>|`Dependent`|libvirt.vm.snapshot.oldestdate|
|Uptime of guest OS|<p>Total time elapsed since the last operating system boot-up (in seconds). Data is collected if Guest OS Add-ons (qemu-guest-agent) are installed, and guest-exec enabled in domain.</p>|`Zabbix agent`|libvirt.vm[guest.uptime,{$HV.USER},{$LIBVIRT.VM.UUID}]|
|VM Uptime|<p>System uptime.</p>|`Zabbix agent`|libvirt.vm[uptime,{$HV.USER},{$LIBVIRT.VM.UUID}]|
|VM state|<p> </p>|`Zabbix agent`|libvirt.vm[state,{$HV.USER},{$LIBVIRT.VM.UUID}]|
|VM Number of virtual CPUs|<p>How many CPUs has this domain</p>|`Zabbix agent`|libvirt.vm[cpu.num, {$HV.USER},{$LIBVIRT.VM.UUID}]|
|Guest OS memory available in %|<p> </p>|`Zabbix agent`|vm.memory.size[pavailable]|
|Guest OS memory used in %|<p> </p>|`Zabbix agent`|vm.memory.utilization|
|VM domain display|<p>URI which can be used to connect to the graphical display of the domain.</p>|`Zabbix agent`|libvirt.vm[domdisplay,{$HV.USER},{$LIBVIRT.VM.UUID}]|
|VM host name|<p>Domain host name.</p>|`Zabbix agent`|libvirt.vm[domhostname,{$HV.USER},{$LIBVIRT.VM.UUID}]|
|VM Get block stats|<p> </p>|`Zabbix agent`|libvirt.vm[blk.stats.get,{$HV.USER},{$LIBVIRT.VM.UUID}]|
|VM Get domain stats|<p> </p>|`Zabbix agent`|libvirt.vm[dom.stat.get,{$HV.USER},{$LIBVIRT.VM.UUID}]|
|VM Get filesystem stats|<p> </p>|`Zabbix agent`|libvirt.vm[fs.stats.get,{$HV.USER},{$LIBVIRT.VM.UUID}]|
|VM Get network stats|<p> </p>|`Zabbix agent`|libvirt.vm[net.stats.get,{$HV.USER},{$LIBVIRT.VM.UUID}]|
|VM Get snapshots|<p> </p>|`Zabbix agent`|libvirt.vm[snapshot.get, {$HV.USER},{$LIBVIRT.VM.UUID}]|

## Triggers

|Name|Description|Expression|Priority|
|----|-----------|----------|--------|
|Domain control != "ok"|<p>-</p>|<p>**Expression**: last(/Libvirt KVM Guest/libvirt.vm[domcontrol,{$HV.USER},{$LIBVIRT.VM.UUID}]) <> "ok"</p><p>**Recovery expression**: </p>|warning|
|QEMU Tools is not running|<p>-</p>|<p>**Expression**: last(/Libvirt KVM Guest/libvirt.vm[tools, {$HV.USER},{$LIBVIRT.VM.UUID}]) = 1</p><p>**Recovery expression**: </p>|warning|
|VM has been rebooted|<p>-</p>|<p>**Expression**: last(/Libvirt KVM Guest/libvirt.vm[guest.uptime,{$HV.USER},{$LIBVIRT.VM.UUID}])&lt;600</p><p>**Recovery expression**: </p>|notice|
|VM has been restarted|<p>-</p>|<p>**Expression**: last(/Libvirt KVM Guest/libvirt.vm[uptime,{$HV.USER},{$LIBVIRT.VM.UUID}])&lt;600</p><p>**Recovery expression**: </p>|warning|
|VM is not running|<p>-</p>|<p>**Expression**: last(/Libvirt KVM Guest/libvirt.vm[state,{$HV.USER},{$LIBVIRT.VM.UUID}]) &lt;> "running"</p><p>**Recovery expression**: </p>|average|
|Snapshots count > 10|<p>-</p>|<p>**Expression**: last(/Libvirt KVM Guest/libvirt.vm.snapshot.count)>10</p><p>**Recovery expression**: </p>|notice|

## Discovery rules

|Name|Description|Type|Key and additional info|
|----|-----------|----|----|
|Disk device/block discovery|<p>Discovery of all disk devices.</p>|`Dependent`|libvirt.vm.blk.discovery|
|Network device discovery|<p>Discovery of all network devices.</p>|`Dependent`|libvirt.vm.net.if.discovery|
|Mounted filesystem discovery|<p>Discovery of all guest file systems.</p>|`Dependent`|libvirt.vm.fs.discovery|

## Item prototypes for Disk device/block discovery

## Item prototypes for Network device discovery

## Item prototypes for Mounted filesystem discovery
