#!/bin/sh

#tc qdisc add dev $device ingress
#tc filter add dev $device parent ffff: protocol ip prio 1 u32 match u32 0 0 flowid 1:1 action connmark action mirred egress redirect dev ifb$ifbdev" "$N"
insmod sch_ingress
insmod act_mirred
insmod cls_fw
insmod sch_htb

DEV=ge00
DOWNLINK=24000

TC=/usr/sbin/tc
FLOWS=8000

CEIL=$DOWNLINK
PRIO_RATE=`expr $CEIL / 3` # Ceiling for prioirty
BE_RATE=`expr $CEIL / 6`   # Min for best effort
BK_RATE=`expr $CEIL / 9`   # Min for background
BE_CEIL=`expr $CEIL - 64`  # A little slop at the top

R2Q=""

tc qdisc del dev $DEV handle ffff: ingress
tc qdisc add dev $DEV handle ffff: ingress
 
tc qdisc del dev ifb0 root 
IFACE=ifb0

tc qdisc add dev $IFACE root handle 1: htb ${RTQ} default 12
tc class add dev $IFACE parent 1: classid 1:1 htb rate ${CEIL}kibit ceil ${CEIL}kibit $ADSLL
tc class add dev $IFACE parent 1:1 classid 1:10 htb rate ${CEIL}kibit ceil ${CEIL}kibit prio 0 $ADSLL
tc class add dev $IFACE parent 1:1 classid 1:11 htb rate 32kibit ceil ${PRIO_RATE}kibit prio 1 $ADSLL
tc class add dev $IFACE parent 1:1 classid 1:12 htb rate ${BE_RATE}kibit ceil ${BE_CEIL}kibit prio 2 $ADSLL
tc class add dev $IFACE parent 1:1 classid 1:13 htb rate ${BK_RATE}kibit ceil ${BE_CEIL}kibit prio 3 $ADSLL

# The calculations (still) needed here are why I wanted to do this in lua first
# all the variables - limit, depth, min, max, redflowlimit are dependent on the
# bandwidth, but scale differently. I don't think RED can be made to work on
# long RTTs, period...

# I'd prefer to use a pre-nat filter but that causes permutation...
# Anyway... need FP (sqrt) from lua to finish this part...

# A depth of 16 is better at low rates, but no lower. I'd argue for a floor of 22
# Packet aggregation suggests 42-64.

tc qdisc add dev $IFACE parent 1:11 handle 110: sfq limit 200 depth 42 flows $FLOWS \
min 16000 max 32000 probability .12 redflowlimit 64000 ${PERTURB} ecn headdrop harddrop divisor 16384
tc qdisc add dev $IFACE parent 1:12 handle 120: sfq limit 300 depth 42 flows $FLOWS \
min 16000 max 32000 probability .12 redflowlimit 64000 ${PERTURB} ecn headdrop harddrop divisor 16384
tc qdisc add dev $IFACE parent 1:13 handle 130: sfq limit 150 depth 42 flows $FLOWS \
min 12000 max 24000 probability .12 redflowlimit 32000 ${PERTURB} ecn headdrop harddrop divisor 16384

tc filter add dev $IFACE parent 1:0 protocol ip prio 1 handle 1 fw classid 1:11
tc filter add dev $IFACE parent 1:0 protocol ip prio 2 handle 2 fw classid 1:12
tc filter add dev $IFACE parent 1:0 protocol ip prio 3 handle 3 fw classid 1:13

# ipv6 support. Note that the handle indicates the fw mark bucket that is looked for

tc filter add dev $IFACE parent 1:0 protocol ipv6 prio 4 handle 1 fw classid 1:11
tc filter add dev $IFACE parent 1:0 protocol ipv6 prio 5 handle 2 fw classid 1:12
tc filter add dev $IFACE parent 1:0 protocol ipv6 prio 6 handle 3 fw classid 1:13

# Arp traffic

tc filter add dev $IFACE parent 1:0 protocol arp prio 7 handle 1 fw classid 1:11

#$TC qdisc add dev ifb0 parent 1:1 handle 10: sfq
#$TC qdisc add dev ifb0 parent 1:2 handle 20: sfq #tbf rate 20000kbit buffer 1600 limit 3000
#$TC qdisc add dev ifb0 parent 1:3 handle 30: sfq                                
#$TC filter add dev ifb0 protocol all pref 1 parent 1: handle 1 fw classid 1:1
#$TC filter add dev ifb0 protocol all pref 2 parent 1: handle 2 fw classid 1:1
#$TC filter add dev ifb0 protocol all pref 2 parent 1: handle 3 fw classid 1:1
#$TC filter add dev ifb0 protocol all pref 2 parent 1: handle 4 fw classid 1:1
#$TC filter add dev ifb0 protocol all pref 2 parent 1: handle 5 fw classid 1:1
#$TC filter add dev ifb0 protocol all pref 2 parent 1: handle 6 fw classid 1:1
#$TC filter add dev ifb0 protocol all pref 2 parent 1: handle 7 fw classid 1:1
#$TC filter add dev ifb0 protocol all pref 2 parent 1: handle 8 fw classid 1:1
#$TC filter add dev ifb0 protocol all pref 2 parent 1: handle 9 fw classid 1:9
ifconfig ifb0 up
# redirect all IP packets arriving in $DEV to ifb0 
# use mark 1 --> puts them onto class 1:1
$TC filter add dev $DEV parent ffff: protocol all prio 10 u32 \
  match u32 0 0 flowid 1:1 \
      action mirred egress redirect dev ifb0
