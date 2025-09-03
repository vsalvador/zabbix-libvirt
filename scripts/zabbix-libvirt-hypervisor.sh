#!/bin/bash

## 30/August/2025
#  (C) Vicente Salvador vsalvador@nabutek.com
#
#  30/08/2025 - Initial version
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

export vTmpResult="/tmp/zabbix_libvirt_kvm.$$.txt"

export ZABBIX_COMMAND=$1
export ZABBIX_OPTION=$2
export VIRSH="sudo $(which virsh) -q"
if [ $# -eq 3 ]; then
   export VIRSH="sudo -u ${3} $(which virsh) -q"
fi

function show_idented {
echo "Resultado 1" > /tmp/file
echo "Resultado 2" >> /tmp/file
echo "Resultado 3" >> /tmp/file
( 
    first="Printing Line of the file:"
    IFS=
    read -r line
    printf "%*s %s\n" ${#first} "$first" "$line"
    while read -r line; do 
        printf "%*s %s\n" ${#first} "" "$line"
    done 
) < /tmp/file

}

function indent_content2 {
    cat ~/.bashrc | paste /dev/null - | expand -2
}

function _param {
    vCommand=${1}
    vOption=${2}
    vConnURI=${3}

    function header {
        if [ "$vOption" = "HEAD" ]; then
            echo_no_nl "${vCommand} : "
        fi
    }

    case $vCommand in
        status)
            show_idented
        ;;

        discovery)
            jbody=""
            sep=""
            for HVUSER in `ps -eaf | grep libvirtd | grep -v grep | awk '{ print $1 }'`; do
                jbody+="$sep"'{"{#LIBVIRT.USER}":"'"${HVUSER}"'"}'
                sep=", "
            done
            echo "[ $jbody ]"
        ;;

        net.if.discovery)
            jbody=""
            sep=""
            while IFS= read -r POOL; do
                IFNAME="$(echo $POOL | $AWK '{ print $1 }')"
                IFSTAT="$(echo $POOL | $AWK '{ print $2 }')"
                IFMAC="$(echo $POOL | $AWK '{ print $3 }')"
                jbody+="$sep"'{"{#IFNAME}":"'"${IFNAME}"'","{#IFMACADDR}":"'"${IFMAC}"'"}'
                sep=", "
            done <<< $($VIRSH iface-list)
            echo "[ $jbody ]"
        ;;
        net.if.linkspeed)
            $VIRSH iface-dumpxml $vOption > $vTmpResult
            if [ $? -ne 0 ]; then
                echo "<interface><bridge><interface><link speed='0' /></interface></bridge></interface>" >> $vTmpResult
            fi
            SPEED=$(xmllint --xpath "string(/interface/bridge/interface/link/@speed)" $vTmpResult)
            [ "$SPEED" = "" ] && echo "99000" || echo $SPEED
            rm -f $vTmpResult
        ;;

        pool.discovery)
            jbody=""
            sep=""
            while IFS= read -r POOL; do
                UUID="${POOL%% *}"
                NAME="$(echo $POOL | $AWK '{ print $2 }')"
                jbody+="$sep"'{"{#POOLNAME}":"'"${NAME}"'","{#POOLUUID}":"'"${UUID}"'"}'
                sep=", "
            done <<< $($VIRSH pool-list --uuid --name)
            echo "[ $jbody ]"
        ;;

        pool.size)
            $VIRSH pool-info ${vOption} --bytes | grep "Capacity:" | awk '{ print $2 }'
        ;;

        pool.free)
            $VIRSH pool-info ${vOption} --bytes | grep "Available:" | awk '{ print $2 }'
        ;;

        pool.pfree)
            TOTAL=$($VIRSH pool-info ${vOption} --bytes | grep "Capacity:" | awk '{ print $2 }')
            FREE=$($VIRSH pool-info ${vOption} --bytes | grep "Available:" | awk '{ print $2 }')
            echo $(( $FREE * 100 / $TOTAL ))
        ;;

        ksm.get)
            PAGESIZE=$(getconf PAGESIZE)

            header
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

      
#When use_zero_pages is/was enabled, the sum of pages_sharing + ksm_zero_pages represents the actual number of pages saved by KSM. if use_zero_pages has never been enabled, ksm_zero_pages is 0.

##A high ratio of pages_sharing to pages_shared indicates good sharing, but a high ratio of pages_unshared to pages_sharing indicates wasted effort. pages_volatile embraces several different kinds of activity, but a high proportion there would also indicate poor use of madvise MADV_MERGEABLE.

#The maximum possible pages_sharing/pages_shared ratio is limited by the max_page_sharing tunable. To increase the ratio max_page_sharing must be increased accordingly.

        ;;
        version.get)
            header
            $VIRSH version 
        ;;
        nodeinfo.get)
            header
            $VIRSH nodeinfo 
        ;;
        nodecpustats.get)
            header
            $VIRSH nodecpustats 
        ;;
        nodememstats.get)
            header
            $VIRSH nodememstats 
        ;;
        sysinfo.get)
            header

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
        uptime)
            header
            ${AWK} '{print $1}' /proc/uptime
        ;;
        vmnum)
            header
            TOTALVM=0
            for HVUSER in `ps -eaf | grep libvirtd | grep -v grep | awk '{ print $1 }'`; do
               NUMVM=`sudo -u $HVUSER $(which virsh) -q list --all --name | wc -l`
               TOTALVM=$(( $TOTALVM + $NUMVM ))
            done
            echo $TOTALVM
        ;;
#        vm.number)
#            $VIRSH list --all --name
#        ;;
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
