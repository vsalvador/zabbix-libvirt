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
#   $1 -> Command
#   $2 -> Libvirt Connect User
#   $3 -> Guest Name or UUID
#
# -------------------------------------------------------------------

if [ "$1" != "discovery" ] && [ "$1" != "vm.get" ] && [ "$1" != "network.get" ] && [ $# -lt 3 ] ; then
  echo "ZBX_NOTSUPPORTED"
  exit 1
fi

# Remove the temporary file when the script finish, with or without success.
trap "rm -f $vTmpResult >/dev/null 2>&1 ; exit " 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
export vTmpResult="/tmp/zabbix_libvirt_guest.$$.txt"
export VIRSH="sudo $(which virsh)"

export ZABBIX_COMMAND=$1
export ZABBIX_GUEST=$3
export ZABBIX_OPTION=$4
if [[ $ZABBIX_GUEST =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
    ZABBIX_GUEST=$( $VIRSH domname $ZABBIX_GUEST )
fi

if [ $# -ge 2 ] && [ $2 != "root" ]; then
   export VIRSH="sudo -u ${2} $(which virsh)"
fi

function _param {
    vCommand=${1}
    vGuest=${2}
    vOption=${3}
    vConnURI=${4}

    function header {
        if [ "$vOption" = "HEAD" ]; then
            echo_no_nl "${vCommand} : "
        fi
    }

    case $vCommand in
        discovery)
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

                $VIRSH dominfo ${VMNAME} > $vTmpResult
                VMUUID=$(grep -i uuid       $vTmpResult | $AWK -F: '{ gsub(/^\s+/, "", $2); print $2 }')
                VMAUTO=$(grep -i autostart  $vTmpResult | $AWK -F: '{ gsub(/^\s+/, "", $2); print $2 }')
                VMPERS=$(grep -i persistent $vTmpResult | $AWK -F: '{ gsub(/^\s+/, "", $2); print $2 }')
                rm -f $vTmpResult

                jbody+="$sep"'{"{#VM.ID}":"'"${VMID}"'","{#VM.NAME}":"'"${VMNAME}"'","{#VM.UUID}":"'"${VMUUID}"'","{#VM.STAT}":"'"${VMSTAT}"'",' 
                jbody+='"{#VM.AUTOSTART}":"'"${VMAUTO}"'","{#VM.PERSISTENT}":"'"${VMPERS}"'",'
                jbody+='"{#HV.USER}":"'"$HVUSER"'","{#HV.NAME}":"'"${HVNAME}"'"}'
                sep=", "$'\n'
            done <<< $( sudo -u $HVUSER $(which virsh) list --all --title | head -n -1 | tail -n +3)

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
            done <<< $($VIRSH domiflist $ZABBIX_GUEST | head -n -1 | tail -n +3)
            echo "[ $jbody ]"
        ;;

        vfs.fs.discovery)
            $VIRSH guestinfo --filesystem $ZABBIX_GUEST > $vTmpResult

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
            $VIRSH guestinfo --filesystem $ZABBIX_GUEST | $EGREP "fs\.${ZABBIX_OPTION}\."
        ;;

        vfs.dev.discovery)
            jbody=""
            sep=""
            while IFS= read -r DEVINFO; do
                DISKNAME="$(echo $DEVINFO | $AWK '{ print $1 }')"
                SOURCE="$(echo $DEVINFO | $AWK '{ print $2 }')"
                jbody+="$sep"'{"{#DISKNAME}":"'"${DISKNAME}"'","{#SOURCE}":"'"${SOURCE}"'"}'
                sep=", "
            done <<< $($VIRSH domblklist $ZABBIX_GUEST | head -n -1 | tail -n +3)
            echo "[ $jbody ]"
        ;;

        blk.info.get)
            $VIRSH domblkinfo $ZABBIX_GUEST $ZABBIX_OPTION
        ;;

        blk.stat.get)
            $VIRSH domblkstat $ZABBIX_GUEST $ZABBIX_OPTION
        ;;

        dom.stat.get)
            $VIRSH domstats --state --cpu-total --balloon --memory --vm $ZABBIX_GUEST
        ;;

        dom.memstat.get)
            $VIRSH dommemstat $ZABBIX_GUEST
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
            done <<< $($VIRSH domifaddr $ZABBIX_GUEST --source arp | head -n -1 | tail -n +3)
            echo '{"network": [ '"$jbody"' ]}'
        ;;

        net.ifstat.get)
            $VIRSH domifstat $ZABBIX_GUEST $ZABBIX_OPTION
        ;;

        snapshot.get)
            COUNT=0
            jbody=""
            sep=""
            while IFS= read -r SNAPSHOT; do
                if [ "$SNAPSHOT" != "" ]; then
                    COUNT=$(( $COUNT + 1 ))
                    NAME="$(echo $SNAPSHOT | $AWK '{ print $1 }')"
                    jbody+="$sep"'{"name":"'"${NAME}"'","createtime":"'"${CTIME}"'","state":"'"${STATE}"'"}'
                    sep=", "
                fi
            done <<< $($VIRSH snapshot-list $ZABBIX_GUEST | head -n -1 | tail -n +3)

            echo '{"snapshot": [ '"$jbody"' ], "count": '"$COUNT"', "latestdate": null, "latestage": 0, "oldestdate": null, "oldestage": 0}'
        ;;


        cpu.num)
            $VIRSH vcpucount $ZABBIX_GUEST | grep "current      live" | awk '{ print $3 }'
        ;;

        domcontrol)
            $VIRSH domcontrol $ZABBIX_GUEST
        ;;

        domdisplay)
            $VIRSH domdisplay $ZABBIX_GUEST
        ;;

        domhostname)
            $VIRSH domhostname $ZABBIX_GUEST
        ;;


        guest.os)
            $VIRSH guestinfo --os $ZABBIX_GUEST
        ;;

        guest.uptime)
            PROCID=$( $VIRSH qemu-agent-command --pretty $ZABBIX_GUEST '{"execute":"guest-exec", "arguments":{"path":"cat", "arg":["/proc/uptime"], "capture-output":true}}' | jq -r '.return.pid')
            $VIRSH qemu-agent-command --pretty $ZABBIX_GUEST '{"execute":"guest-exec-status", "arguments":{"pid":'$PROCID'}}' | jq -r '.return."out-data"' | base64 -d | awk '{ print $1 }'
        ;;

        uptime)
            CURRENT=$( date '+%s' )
            START=$( ps -D '%s' -eo lstart,times,comm,args | grep guest=${ZABBIX_GUEST} | grep -v grep | awk '{ print $1 }' )

            echo $(( $CURRENT - $START ))
        ;;

        tools)
            $VIRSH qemu-agent-command $ZABBIX_AGENT '{}' 2>&1 | grep -c "Guest agent is not responding" 
        ;;

        state)
            $VIRSH domstate $ZABBIX_GUEST
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
