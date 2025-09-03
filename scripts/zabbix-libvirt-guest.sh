#!/bin/bash

## 30/August/2025
#  (C) Vicente Salvador vsalvador@nabutek.com
#
#  30/08/2025 - Initial version
#
# Script to help collect information from Libvirt Guest Machines using virsh command
#
# This script was prepared to be used with Zabbix Agent , create 
# /etc/zabbix/zabbix-agentd.d/zabbix-libvirt.conf 
#   UserParameter=libvirt.hv[*],/etc/zabbix/zabbix-libvirt-hypervisor.sh $1 $2 $3 $4
#   UserParameter=libvirt.vm[*],/etc/zabbix/zabbix-libvirt-guest.sh $1 $2 $3 $4
#
# Zabbix execute this shell using zabbix user. Some items requires other permisions
# Create/Edit sudoers file at /etc/sudoers.d/zabbix with this content:
#
# Defaults:zabbix !requiretty
# Defaults:zabbix !syslog
# zabbix ALL=(ALL) NOPASSWD: /usr/bin/virsh

GREP=grep
EGREP=$([ `uname` == "SunOS" ] && echo "egrep" || echo "grep -E");
AWK=awk
SED=sed
TR=tr
CUT=cut
DATE=date

echo_no_nl() {
    echo -n "$1"
}

# -------------------------------------------------------------------
# PARAMETERS
#   $1 -> (required) Command
#   $2 -> (required) Libvirt Connect User
#   $3 -> (required) Guest Name or UUID
#   $4 -> (optional) Additional identification for some commands
# -------------------------------------------------------------------

if [ "$1" != "discovery" ] && [ "$1" != "vm.get" ] && [ "$1" != "network.get" ] && [ $# -lt 3 ] ; then
  echo "ZBX_NOTSUPPORTED"
  exit 1
fi

# Remove the temporary file when the script finish, with or without success.
trap "rm -f $vTmpResult >/dev/null 2>&1 ; exit " 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
export vTmpResult="/tmp/zabbix_libvirt_guest.$$.txt"

export ZABBIX_COMMAND=$1
export ZABBIX_DOMAIN=$3
export ZABBIX_OPTION=$4

# If VM is a user domain and not a system domain, impersonate as the user running the VM
export VIRSH="sudo $(which virsh)"
if [ $# -ge 2 ] && [ $2 != "root" ]; then
   export VIRSH="sudo -u ${2} $(which virsh)"
fi

# If ZABBIX_DOMAIN is a VM UUID, convert it to domain name
if [[ $ZABBIX_DOMAIN =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
    ZABBIX_DOMAIN=$( $VIRSH -q domname $ZABBIX_DOMAIN )
fi

function _param {
    vCommand=${1}
    vGuest=${2}
    vOption=${3}

    function header {
        if [ "$vOption" = "HEAD" ]; then
            echo_no_nl "${vCommand} : "
        fi
    }

    case $vCommand in
        discovery)
            # We need title headers to know where VM title starts
            HEADER=$($VIRSH list --all --title | head -n +1 )
            PREFIX="${HEADER%%Title*}"
            TITLECOL=${#PREFIX}

            jbody=""
            sep=""
            for HVUSER in `ps -eaf | grep libvirtd | grep -v grep | awk '{ print $1 }'`; do

            while IFS= read -r VM; do
                HVNAME=$( hostname -s )
                VMID=$(echo $VM | $AWK '{ print $1 }')
                VMNAME=$(echo $VM | $AWK '{ print $2 }')
                VMSTAT=$(echo $VM | $AWK '{ print $3 }')
                VMTITLE=$($CUT -c $((${TITLECOL}+1))- <<<"$VM")

                $VIRSH -q dominfo ${VMNAME} > $vTmpResult
                VMUUID=$(grep -i uuid       $vTmpResult | $AWK -F: '{ gsub(/^\s+/, "", $2); print $2 }')
                VMAUTO=$(grep -i autostart  $vTmpResult | $AWK -F: '{ gsub(/^\s+/, "", $2); print $2 }')
                VMPERS=$(grep -i persistent $vTmpResult | $AWK -F: '{ gsub(/^\s+/, "", $2); print $2 }')
                rm -f $vTmpResult

                jbody+="$sep"'{"{#VM.ID}":"'"${VMID}"'","{#VM.NAME}":"'"${VMNAME}"'","{#VM.UUID}":"'"${VMUUID}"'","{#VM.STAT}":"'"${VMSTAT}"'",' 
                jbody+='"{#VM.AUTOSTART}":"'"${VMAUTO}"'","{#VM.PERSISTENT}":"'"${VMPERS}"'",'
                jbody+='"{#HV.USER}":"'"$HVUSER"'","{#HV.NAME}":"'"${HVNAME}"'"}'
                sep=", "$'\n'
            done <<< $( sudo -u $HVUSER $(which virsh) -q list --all --title)

            done
            echo "[ $jbody ]"
        ;;

        net.if.discovery)
            jbody=""
            sep=""
            while IFS= read -r IFINFO; do
                IFNAME="$(echo $IFINFO | $AWK '{ print $1 }')"
                IFBACKING="$(echo $IFINFO | $AWK '{ print $3 }')"
                IFDESC="$(echo $IFINFO | $AWK '{ print $5 }')"
                jbody+="$sep"'{"{#IFNAME}":"'"${IFNAME}"'","{#IFDESC}":"'"${IFDESC}"'","{#IFBACKINGDEVICE}":"'"${IFBACKING}"'"}'
                sep=", "
            done <<< $($VIRSH domiflist -q $ZABBIX_DOMAIN)
            echo "[ $jbody ]"
        ;;

        vfs.fs.discovery)
            $VIRSH -q guestinfo --filesystem $ZABBIX_DOMAIN > $vTmpResult

            FSCOUNT=$( cat $vTmpResult | grep "fs.count" | awk -F: '{ print $2 }')
            jbody=""
            sep=""
            for FSNUM in `seq 0 $(( $FSCOUNT - 1 ))`; do
                FSNAME=$(cat $vTmpResult | grep "fs.${FSNUM}.mountpoint" | $AWK -F': ' '{ print $2 }')
                FSPART=$(cat $vTmpResult | grep "fs.${FSNUM}.name"       | $AWK -F': ' '{ print $2 }')
                FSTYPE=$(cat $vTmpResult | grep "fs.${FSNUM}.fstype"     | $AWK -F': ' '{ print $2 }')

                jbody+="$sep"'{"{#FSNUM}":"'"${FSNUM}"'","{#FSNAME}":"'"${FSNAME}"'","{#FSPART}":"'"${FSPART}"'","{#FSTYPE}":"'"${FSTYPE}"'"}'
                sep=", "
            done

            rm -f $vTmpResult
            echo "[ $jbody ]"
        ;;

        vfs.fs.get)
            $VIRSH -q guestinfo --filesystem $ZABBIX_DOMAIN | $EGREP "fs\.${ZABBIX_OPTION}\."
        ;;

        vfs.dev.discovery)
            jbody=""
            sep=""
            while IFS= read -r DEVINFO; do
                DISKNAME="$(echo $DEVINFO | $AWK '{ print $1 }')"
                SOURCE="$(echo $DEVINFO | $AWK '{ print $2 }')"
                jbody+="$sep"'{"{#DISKNAME}":"'"${DISKNAME}"'","{#SOURCE}":"'"${SOURCE}"'"}'
                sep=", "
            done <<< $($VIRSH -q domblklist $ZABBIX_DOMAIN)
            echo "[ $jbody ]"
        ;;

        # Combined JSON for LLD and statistics for block devices (disks)
        blk.stats.get)
            $VIRSH -q domstats $ZABBIX_DOMAIN --block > $vTmpResult

            BLKCOUNT=$( cat $vTmpResult | grep "block.count" | awk -F= '{ print $2 }')
            jbody=""
            sep=""
            for BLKNUM in `seq 0 $(( $BLKCOUNT - 1 ))`; do
                BLKOBJ=$( cat $vTmpResult | grep block.${BLKNUM} | sed "s/^\s*block.${BLKNUM}.//" | \
                            $AWK -F= '{ printf "{\"key\":\"%s\", \"value\":\"%s\"}\n", $1, $2 }' | \
                            jq -s 'reduce .[] as $item ({}; . + { ($item.key): ($item.value | tonumber? // $item.value) })')
                jbody+="${sep}${BLKOBJ}"
                sep=", "
            done
            rm -f $vTmpResult
            echo "[ $jbody ]"
        ;;

        fs.stats.get)
            $VIRSH -q guestinfo --filesystem $ZABBIX_DOMAIN > $vTmpResult

            FSCOUNT=$( cat $vTmpResult | grep "fs.count" | awk -F: '{ print $2 }')
            jbody=""
            sep=""
            for FSNUM in `seq 0 $(( $FSCOUNT - 1 ))`; do
                FSOBJ=$( cat $vTmpResult | grep fs.${FSNUM} | sed "s/^\s*fs.${FSNUM}.//" | \
                            $AWK -F: '{ gsub(/\s+$/, "", $1); gsub(/^\s+/, "", $2); printf "{\"key\":\"%s\", \"value\":\"%s\"}\n", $1, $2 }' | \
                            jq -s 'reduce .[] as $item ({}; . + { ($item.key): ($item.value | tonumber? // $item.value) })' | \
                            jq    'def to_disk_array: { alias: .["disk.0.alias"], device: .["disk.0.device"] };                          
                                   del(.["disk.count"]) 
                                   | with_entries(select(.key | startswith("disk.0") | not)) 
                                   + { disks: to_disk_array }' )
                jbody+="${sep}${FSOBJ}"
                sep=", "
            done
            rm -f $vTmpResult
            echo "[ $jbody ]"
        ;;

        net.stats.get)
            while IFS= read -r NETIF; do
                read IFNAME TYPE SOURCE MODEL MAC <<< "$NETIF"
                if [ "$IFNAME" != "-" ]; then
                    read IFNAME2 MAC2 PROTOCOL IP <<< $($VIRSH -q domifaddr vm01 --interface vnet4 --source arp --full)
                    jbody+="${sep}{\"name\":\"${IFNAME}\",\"ipaddr\":\"${IP}\",\"type\":\"$TYPE\",\"source\":\"$SOURCE\",\"model\":\"$MODEL\",\"mac\":\"$MAC\""
                    while IFS= read -r STATS; do
                        jbody+=$(echo $STATS | $AWK '{ printf ",\"%s\":\"%s\"\n", $1, $2 }')
                    done <<< $($VIRSH -q domifstat $ZABBIX_DOMAIN --interface $IFNAME | sed "s/$IFNAME\s*//" )
                    jbody+='}'
                    sep=", "
                fi
            done <<< $($VIRSH -q domiflist $ZABBIX_DOMAIN)
            echo "[ $jbody ]" 
        ;;

        dom.stat.get)
            $VIRSH -q domstats --state --cpu-total --balloon --memory --vm $ZABBIX_DOMAIN
        ;;

        dom.memstat.get)
            $VIRSH -q dommemstat $ZABBIX_DOMAIN
        ;;

        vm.get)
            HEADER=$($VIRSH list --all --title | head -n +1 )
            PREFIX="${HEADER%%Title*}"
            TITLECOL=${#PREFIX}

            jbody=""
            sep=""
            while IFS= read -r VM; do
                HVNAME=$( hostname -s )
                VMID=$(echo $VM | $AWK '{ print $1 }')
                VMNAME=$(echo $VM | $AWK '{ print $2 }')
                VMSTAT=$(echo $VM | $AWK '{ print $3 }')
                VMTITLE=$($CUT -c $((${TITLECOL}+1))- <<<"$VM")

                $VIRSH dominfo ${VMNAME} > $vTmpResult
                VMUUID=$(grep -i uuid       $vTmpResult | $AWK -F: '{ gsub(/^\s+/, "", $2); print $2 }')
                VMAUTO=$(grep -i autostart  $vTmpResult | $AWK -F: '{ gsub(/^\s+/, "", $2); print $2 }')
                VMPERS=$(grep -i persistent $vTmpResult | $AWK -F: '{ gsub(/^\s+/, "", $2); print $2 }')
                rm -f $vTmpResult

                jbody+="$sep"'{"id":"'"${VMID}"'","name":"'"${VMNAME}"'","uuid":"'"${VMUUID}"'","stat":"'"${VMSTAT}"'",' 
                jbody+='"autostart":"'"${VMAUTO}"'","title":"'"${VMTITLE}"'","persistent":"'"${VMPERS}"'","hv.name":"'"${HVNAME}"'"}'
                sep=", "$'\n'
            done <<< $($VIRSH list --all --title | head -n -1 | tail -n +3)
            echo "[ $jbody ]"
        ;;

        net.ifaddr.get)
            jbody=""
            sep=""
            while IFS= read -r NETIF; do
                IFNAME="$(echo $NETIF | $AWK '{ print $1 }')"
                IFMAC="$(echo $NETIF | $AWK '{ print $2 }')"
                IFPROT="$(echo $NETIF | $AWK '{ print $3 }')"
                IFADDR="$(echo $NETIF | $AWK '{ print $4 }')"
                jbody+="$sep"'{"name":"'"${IFNAME}"'","macaddress":"'"${IFMAC}"'","protocol":"'"${IFPROT}"'","ipaddress":"'"${IFADDR}"'"}'
                sep=", "
            done <<< $($VIRSH -q domifaddr $ZABBIX_DOMAIN --source arp)
            echo '{"network": [ '"$jbody"' ]}'
        ;;

        net.ifstat.get)
            $VIRSH -q domifstat $ZABBIX_DOMAIN $ZABBIX_OPTION
        ;;

        snapshot.get)
            jbody=""
            sep=""
            while IFS= read -r SNAPSHOT; do
                if [ "$SNAPSHOT" != "" ]; then
                    CTIME=$(echo "$SNAPSHOT" | awk -F"  " '{ print $2 }')
                    UTIME=$(date +%s -d "$CTIME" )
                    jbody+="$sep"$(echo "$SNAPSHOT" | $AWK -v my_utime="$UTIME" -F"  " '{ printf "{\"name\":\"%s\", \"utime\":%d, \"createtime\":\"%s\", \"state\":\"%s\"}\n", $1, my_utime, $2, $3 }')
                    sep=", "
                fi
            done <<< $($VIRSH -q snapshot-list $ZABBIX_DOMAIN)

            echo "[ $jbody ]"
        ;;

        cpu.num)
            $VIRSH -q vcpucount $ZABBIX_DOMAIN | $EGREP "current\s+live" | awk '{ print $3 }'
        ;;

        domcontrol)
            $VIRSH -q domcontrol $ZABBIX_DOMAIN
        ;;

        domdisplay)
            $VIRSH -q domdisplay $ZABBIX_DOMAIN
        ;;

        domhostname)
            $VIRSH -q domhostname $ZABBIX_DOMAIN
        ;;

        guest.os)
            $VIRSH -q guestinfo --os $ZABBIX_DOMAIN
        ;;

        guest.uptime)
            PROCID=$( $VIRSH qemu-agent-command --pretty $ZABBIX_DOMAIN '{"execute":"guest-exec", "arguments":{"path":"cat", "arg":["/proc/uptime"], "capture-output":true}}' | jq -r '.return.pid')
            $VIRSH qemu-agent-command --pretty $ZABBIX_DOMAIN '{"execute":"guest-exec-status", "arguments":{"pid":'$PROCID'}}' | jq -r '.return."out-data"' | base64 -d | awk '{ print $1 }'
        ;;

        uptime)
            CURRENT=$( date '+%s' )
            START=$( ps -D '%s' -eo lstart,times,comm,args | grep guest=${ZABBIX_DOMAIN} | grep -v grep | awk '{ print $1 }' )

            echo $(( $CURRENT - $START ))
        ;;

        tools)
            $VIRSH qemu-agent-command $ZABBIX_AGENT '{}' 2>&1 | grep -c "Guest agent is not responding" 
        ;;

        state)
            $VIRSH -q domstate $ZABBIX_DOMAIN
        ;;

        *) echo "ZBX_NOTSUPPORTED"
        ;;
    esac

}


###
##############################################
if [ "$ZABBIX_COMMAND" = "all" ] ; then
  for x in status version nodeinfo \
           nodecpustats nodememstats \
           uptime sysinfo
  do
    _param $x HEAD
  done
else
  _param $ZABBIX_COMMAND $ZABBIX_OPTION
fi
