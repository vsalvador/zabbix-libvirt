#!/bin/bash

## 30/August/2025
#  (C) Vicente Salvador vsalvador@nabutek.com
#
#  10/04/2025 - Split IWA metrics to zabiwa to allow shc compiler to work
#
# Script to help collect information from Libvirt hypervisor using virsh command
#
# This script was prepared to be used with Zabbix Agent , create
# /etc/zabbix/zabbix-agentd.d/zabbix-libvirt.conf 
#   UserParameter=libvirt.hv[*],/etc/zabbix/zabbix-libvirt-hypervisor.sh $1 $2 $3 $4
#   UserParameter=libvirt.vm[*],/etc/zabbix/zabbix-libvirt-guest.sh $1 $2 $3 $4

# Zabbix execute this shell using zabbix user. Some items requires other permisions
# Create/Edit sudoers file at /etc/sudoers.d/zabbix with this content:
#
# Defaults:zabbix !requiretty
# Defaults:zabbix !syslog
# zabbix ALL=(ALL) NOPASSWD: /usr/bin/virsh
#

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
#   $2 -> Option
#   $3 -> Libvirt Connect URI
#
# -------------------------------------------------------------------
if [ $# -lt 1 ] ; then
  echo "ZBX_NOTSUPPORTED"
  exit 1
fi

# Remove the temporary file when the script finish, with or without success.
trap "rm -f $vTmpResult >/dev/null 2>&1 ; exit " 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15

export vTmpResult="/tmp/zabbix_libvirt_hv.$$.txt"

export ZABBIX_COMMAND=$1
export ZABBIX_OPTION=$3
export VIRSH="sudo $(which virsh)"
if [ $# -ge 2 ]; then
   export VIRSH="sudo -u ${2} $(which virsh)"
fi

function _param {
    vCommand=${1}
    vOption=${2}

    case $vCommand in

        # --------------------------------------------------------
        # LLD Discovery methods
        # --------------------------------------------------------
        discovery)
            jbody=""
            sep=""
            for HVUSER in `ps -eaf | grep libvirtd | grep -v grep | awk '{ print $1 }'`; do
                jbody+="$sep"'{"{#LIBVIRT.USER}":"'"${HVUSER}"'"}'
                sep=", "
            done
            echo "[ $jbody ]"
        ;;

        vm.discovery)
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

        # --------------------------------------------------------
        # Getters
        # --------------------------------------------------------
        net.stats.get)
            ifstat --json $(  $VIRSH -q iface-list | awk '{ print $1 }' | paste -s -d' ' ) | \
            jq '.kernel | to_entries | map({name: .key} + .value)'
            ## jq '.kernel |= with_entries(.value.name = .key)'
        ;;

        pool.stats.get)
            jbody=""
            sep=""
            for HVUSER in `ps -eaf | grep libvirtd | grep -v grep | awk '{ print $1 }'`; do
                VIRSH="sudo -u $HVUSER $(which virsh)"

                while IFS= read -r POOLNAME; do
                    [ "$POOLNAME" = "" ] && continue;

                    NAME="${POOLNAME%% *}"

                    $VIRSH pool-info "${NAME}" --bytes  > $vTmpResult
                    UUID=$(grep "UUID:" $vTmpResult | awk '{ print $2 }')
                    STAT=$(grep "State:" $vTmpResult | awk '{ print $2 }')
                    AUTO=$(grep "Autostart:" $vTmpResult | awk '{ print $2 }')
                    SIZE=$(grep "Capacity:" $vTmpResult | awk '{ print $2 }')
                    FREE=$(grep "Available:" $vTmpResult | awk '{ print $2 }')
                    ALLOC=$(grep "Allocation:" $vTmpResult | awk '{ print $2 }')
                    PFREE=$(( FREE * 100 / SIZE ))
                    rm -f $vTmpResult

                    jbody+="${sep}{"
                    jbody+="\"name\":\"${NAME}\",\"hvuser\":\"${HVUSER}\",\"uuid\":\"${UUID}\",\"state\":\"${STAT}\",\"autostart\":\"${AUTO}\","
                    jbody+="\"capacity\":\"${SIZE}\",\"allocation\":\"${ALLOC}\",\"free\":\"${FREE}\",\"pfree\":\"${PFREE}\""
                    jbody+="}"
                    sep=", "
                done <<< $($VIRSH pool-list --name --all)
            done

            echo "[ $jbody ]"
        ;;

        ksm.get)
            PAGESIZE=$(getconf PAGESIZE)

            # KSM can save memory by merging identical pages, but also can consume additional memory, 
            # because it needs to generate a number of rmap_items to save each scanned page’s brief rmap information. 
            # Some of these pages may be merged, but some may not be abled to be merged after being checked several times, which are unprofitable memory consumed.
            echo general_profit:$(cat /sys/kernel/mm/ksm/general_profit)
            # memory being scanned for ksm
            echo memory_scanned:$(($PAGESIZE * $(cat /sys/kernel/mm/ksm/pages_scanned) ))
            # how many shared memory are being used
            echo memory_shared:$(($PAGESIZE * $(cat /sys/kernel/mm/ksm/pages_shared) ))
            # how many more sites are sharing them i.e. how much saved
            echo memory_sharing:$(($PAGESIZE * $(cat /sys/kernel/mm/ksm/pages_sharing) ))
            # how many memory unique but repeatedly checked for merging
            echo memory_unshared:$(($PAGESIZE * $(cat /sys/kernel/mm/ksm/pages_unshared) ))
            # how many memory changing too fast to be placed in a tree
            echo memory_volatile:$(($PAGESIZE * $(cat /sys/kernel/mm/ksm/pages_volatile) ))
            # how many memory did the “smart” page scanning algorithm skip
            echo memory_skipped:$(($PAGESIZE * $(cat /sys/kernel/mm/ksm/pages_skipped) ))
            # the number of KSM pages that hit the max_page_sharing limit
            echo stable_node_chains: $(cat /sys/kernel/mm/ksm/stable_node_chains)
            # number of duplicated KSM pages
            echo stable_node_dups: $(cat /sys/kernel/mm/ksm/stable_node_dups)
            # how many zero pages that are still mapped into processes were mapped by KSM when deduplicating
            echo ksm_zero_pages: $(cat /sys/kernel/mm/ksm/ksm_zero_pages)
            echo ksm_zero_memory:$(($PAGESIZE * $(cat /sys/kernel/mm/ksm/ksm_zero_pages) ))


            # When use_zero_pages is/was enabled, the sum of pages_sharing + ksm_zero_pages represents
            # the actual number of pages saved by KSM. if use_zero_pages has never been enabled, ksm_zero_pages is 0.
            # A high ratio of pages_sharing to pages_shared indicates good sharing, but a high ratio of
            # pages_unshared to pages_sharing indicates wasted effort. pages_volatile embraces several different
            # kinds of activity, but a high proportion there would also indicate poor use of madvise MADV_MERGEABLE.
        ;;
        version.get)
            $VIRSH version 
        ;;
        nodeinfo.get)
            $VIRSH nodeinfo
            $VIRSH nodecpumap
        ;;
        nodecpu.stats.get)
            $VIRSH nodecpustats 
        ;;
        nodemem.stats.get)
            $VIRSH nodememstats 
        ;;
        sysinfo.get)
            $VIRSH sysinfo > $vTmpResult

            echo "bios.version:    $(xmllint --xpath "string(/sysinfo/bios/entry[@name='version'])" $vTmpResult)"
            echo "bios.date:       $(xmllint --xpath "string(/sysinfo/bios/entry[@name='date'])" $vTmpResult)"
            echo "system.manufact: $(xmllint --xpath "string(/sysinfo/system/entry[@name='manufacturer'])" $vTmpResult)"
            echo "system.product:  $(xmllint --xpath "string(/sysinfo/system/entry[@name='product'])" $vTmpResult)"
            echo "system.uuid:     $(xmllint --xpath "string(/sysinfo/system/entry[@name='uuid'])" $vTmpResult)"
            echo "processor.manufact:  $(xmllint --xpath "string(/sysinfo/processor/entry[@name='manufacturer'])" $vTmpResult)"
            echo "processor.version:   $(xmllint --xpath "string(/sysinfo/processor/entry[@name='version'])" $vTmpResult)"
            echo "processor.max_speed: $(xmllint --xpath "string(/sysinfo/processor/entry[@name='max_speed'])" $vTmpResult)"
            rm -f $vTmpResult
        ;;

        # --------------------------------------------------------
        # Network methods
        # --------------------------------------------------------
        net.if.linkspeed)
            $VIRSH iface-dumpxml $vOption > $vTmpResult
            if [ $? -ne 0 ]; then
                echo "<interface><bridge><interface><link speed='0' /></interface></bridge></interface>" >> $vTmpResult
            fi
            SPEED=$(xmllint --xpath "string(/interface/bridge/interface/link/@speed)" $vTmpResult)
            [ "$SPEED" = "" ] && echo "99000" || echo $SPEED
            rm -f $vTmpResult
        ;;

        # --------------------------------------------------------
        # System and VM methods
        # --------------------------------------------------------
        uptime)
            ${AWK} '{print $1}' /proc/uptime
        ;;
        vmnum)
            TOTALVM=0
            for HVUSER in `ps -eaf | grep libvirtd | grep -v grep | awk '{ print $1 }'`; do
               NUMVM=`sudo -u $HVUSER $(which virsh) list --all --name | head -n -1 | wc -l`
               TOTALVM=$(( $TOTALVM + $NUMVM ))
            done
            echo $TOTALVM
        ;;
        vm.number)
            $VIRSH -q list --all --name | wc -l
        ;;

        *) echo "ZBX_NOTSUPPORTED"
        ;;
    esac
}

###
##############################################

_param $ZABBIX_COMMAND $ZABBIX_OPTION
