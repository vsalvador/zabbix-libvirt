# zabbix-libvirt
This template set is designed for the deployment of libvirtd based KVM monitoring.

    The template "Libvirt KVM" should be linked to the host where the VM are deployed.
    The template "Libvirt KVM Guest" is used in discovery and normally should not be manually linked to a host.

Inspired in the current Zabbix VMware templates, uses virsh command to get status and statistics of hypervisor. Both system and user virtual machines are identified in the host and a new host is created by the discovery rule. This zabbix host represent a virtual machine and the template "Libvirt KVM Guest" is linked automaticaly to this host.

Tested on:
> RHEL 10.0
> Zabbix 7.4.x

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

### Monitored items

* CPU Statistics - on hypervisor and all libvirt guests
* Memory usage - on hypervisor and all libvirt guests
* Disk operations for each disk - on hypervisor and all libvirt guests
* Network interface packets and octets - on hypervisor and all libvirt guests
