#!/bin/sh

# On starting an interface, apply the right debloating
# stratagies

# /sys/class/net/*/brforward shows a bridge
# What indicates ppp?

SYSPATH=/sys/class/net/
#DEBLOAT_LOG=/tmp/debloat.log
DEBLOAT_LOG=/dev/null

# Circumstances alter debloating strategies
# and knowing what sort of interface is coming
# up determines the scheme. We can't depend
# on the name, either.

# 0 unknown
# 1 localhost
# 2 ifb intermediate functional block or imq
# 3 ethernet
# 4 bridge
# 5 ethernet
# 6 tunnel (gre cat /sys/class/net/gre0/type = 778) sit=776

detect_interface_type() {
local DEV=$1
local devtype=3

[ -h $SYSPATH/$DEV ] && devtype=0
[ -h $SYSPATH/$DEV/phy80211 ] && devtype=1
[ -d $SYSPATH/$DEV/brif ] && devtype=2

}

# 0 unknown
# 1 monitor
# 2 AP
# 3 STA
# 4 AD-HOC


determine_wireless_type {
local DEV=$1
[ -h $SYSPATH/${DEV} ] && 
}

debloat_interface() {

case $devtype in
	0) ip link set $DEV txqueuelen 8 ;;
	1) ip link set $DEV txqueuelen 37 ;;
	2) echo 'do something sane on a bridge' >> $DEBLOAT_LOG ;;
	*) echo 'unknown interface type' >> $DEBLOAT_LOG ;;
esac
}

[ "$ACTION" = "ifup" ] && debloat_interface $DEVICE >> $DEBLOAT_LOG
