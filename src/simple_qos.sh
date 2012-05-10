#!/bin/sh
# Cero3 Shaper
# A 3 bin sfqred and ipv6 enabled shaping script for
# ethernet gateways, with an eye towards working well
# with wireless with uplinks in the 2Mbit to 25Mbit 
# range. It ain't done yet, and is cerowrt specific
# in that it depends on clearly identifying the
# internal interfaces via a pattern match.

# Copyright (C) 2012 Michael D Taht
# GPLv2

# Compared to the complexity that debloat had become
# this cleanly shows a means of going from diffserv marking
# to prioritization using the current tools (ip(6)tables
# and tc. I note that the complexity of debloat exists for
# a reason, and it is expected that script is run first
# to setup various other parameters such as BQL and ethtool.
# (And that the debloat script has setup the other interfaces)

[ -e /etc/functions.sh ] && . /etc/functions.sh || . ./functions.sh

# You need to jiggle these parameters

UPLINK=2000
DOWNLINK=20000
DEV=ifb0
IFACE=ge00
DEPTH=42
TC=/usr/sbin/tc
FLOWS=8000
PERTURB="perturb 0" # Permutation is costly, disable
FLOWS=16000 # 
BQL_MAX=3000 # it is important to factor this into the RED calc

CEIL=$UPLINK
MTU=1500
ADSLL=""
# PPOE=yes

#config interface ge00
#        option classgroup  "Default"
#        option enabled      0
#        option upload       128
#        option download     1024

# uci get aqm.enable
#
# You shouldn't need to touch anything here  

if [ -s "$PPOE" ] 
then
	OVERHEAD=40
	LINKLAYER=adsl
	ADSLL="linklayer ${LINKLAYER} overhead ${OVERHEAD}"
fi

ipt() {
iptables $*
ip6tables $*
}

ipt_setup() {

ipt -t mangle -F
ipt -t mangle -N QOS_MARK

ipt -t mangle -A QOS_MARK -j MARK --set-mark 0x2
# You can go further with classification but...
ipt -t mangle -A QOS_MARK -m dscp --dscp-class CS1 -j MARK --set-mark 0x3
ipt -t mangle -A QOS_MARK -m dscp --dscp-class CS6 -j MARK --set-mark 0x1
ipt -t mangle -A QOS_MARK -m dscp --dscp-class EF -j MARK --set-mark 0x1
ipt -t mangle -A QOS_MARK -m dscp --dscp-class AF42 -j MARK --set-mark 0x1
ipt -t mangle -A QOS_MARK -m tos --tos Minimize-Delay -j MARK --set-mark 0x1

# and it might be a good idea to do it for udp tunnels too

# Turn it on. Preserve classification if already performed

ipt -t mangle -A POSTROUTING -o $DEV -m mark --mark 0x00 -g QOS_MARK 
ipt -t mangle -A POSTROUTING -o $IFACE -m mark --mark 0x00 -g QOS_MARK 

ipt -t mangle -A PREROUTING -i s+ -p tcp -m tcp --tcp-flags SYN,RST,ACK SYN -j MARK --set-mark 0x01
# Not sure if this will work. Encapsulation is a problem period
ipt -t mangle -A PREROUTING -i vtun+ -p tcp -j MARK --set-mark 0x2 # tcp tunnels need ordering

# Emanating from router, do a little more optimization
# but don't bother with it too much. 

ipt -t mangle -A OUTPUT -p udp -m multiport --ports 123,53 -j DSCP --set-dscp-class AF42

#Not clear if the second line is needed
#ipt -t mangle -A OUTPUT -o $IFACE -g QOS_MARK

}


# TC rules

egress() {

CEIL=${UPLINK}
PRIO_RATE=`expr $CEIL / 3` # Ceiling for prioirty
BE_RATE=`expr $CEIL / 6`   # Min for best effort
BK_RATE=`expr $CEIL / 9`   # Min for background
BE_CEIL=`expr $CEIL - 64`  # A little slop at the top

R2Q=""

if [ "$CEIL" -lt 1000 ]
then
	R2Q="rtq 1"
fi

tc qdisc del dev $IFACE root
tc qdisc add dev $IFACE root handle 1: htb ${RTQ} default 12
tc class add dev $IFACE parent 1: classid 1:1 htb rate ${CEIL}kbit ceil ${CEIL}kbit $ADSLL
tc class add dev $IFACE parent 1:1 classid 1:10 htb rate ${CEIL}kbit ceil ${CEIL}kbit prio 0 $ADSLL
tc class add dev $IFACE parent 1:1 classid 1:11 htb rate 128kbit ceil ${PRIO_RATE}kbit prio 1 $ADSLL
tc class add dev $IFACE parent 1:1 classid 1:12 htb rate ${BE_RATE}kbit ceil ${BE_CEIL}kbit prio 2 $ADSLL
tc class add dev $IFACE parent 1:1 classid 1:13 htb rate ${BK_RATE}kbit ceil ${BE_CEIL}kbit prio 3 $ADSLL

# The calculations (still) needed here are why I wanted to do this in lua first
# all the variables - limit, depth, min, max, redflowlimit are dependent on the
# bandwidth, but scale differently. I don't think RED can be made to work on
# long RTTs, period...

# I'd prefer to use a pre-nat filter but that causes permutation...
# Anyway... need FP (sqrt) from lua to finish this part...

# A depth of 16 is better at low rates, but no lower. I'd argue for a floor of 22
# Packet aggregation suggests 42-64.

tc qdisc add dev $IFACE parent 1:11 handle 110: codel
tc qdisc add dev $IFACE parent 1:12 handle 120: codel
tc qdisc add dev $IFACE parent 1:13 handle 130: codel

tc filter add dev $IFACE parent 1:0 protocol ip prio 1 handle 1 fw classid 1:11
tc filter add dev $IFACE parent 1:0 protocol ip prio 2 handle 2 fw classid 1:12
tc filter add dev $IFACE parent 1:0 protocol ip prio 3 handle 3 fw classid 1:13

# ipv6 support. Note that the handle indicates the fw mark bucket that is looked for

tc filter add dev $IFACE parent 1:0 protocol ipv6 prio 4 handle 1 fw classid 1:11
tc filter add dev $IFACE parent 1:0 protocol ipv6 prio 5 handle 2 fw classid 1:12
tc filter add dev $IFACE parent 1:0 protocol ipv6 prio 6 handle 3 fw classid 1:13

# Arp traffic

tc filter add dev $IFACE parent 1:0 protocol arp prio 7 handle 1 fw classid 1:11

}

ingress() {

insmod sch_ingress
insmod act_mirred
insmod cls_fw
insmod sch_htb

CEIL=$DOWNLINK
PRIO_RATE=`expr $CEIL / 3` # Ceiling for prioirty
BE_RATE=`expr $CEIL / 6`   # Min for best effort
BK_RATE=`expr $CEIL / 9`   # Min for background
BE_CEIL=`expr $CEIL - 64`  # A little slop at the top

R2Q=""

tc qdisc del dev $IFACE handle ffff: ingress
tc qdisc add dev $IFACE handle ffff: ingress
 
tc qdisc del dev $DEV root 
tc qdisc add dev $DEV root handle 1: htb ${RTQ} default 12
tc class add dev $DEV parent 1: classid 1:1 htb rate ${CEIL}kibit ceil ${CEIL}kibit $ADSLL
tc class add dev $DEV parent 1:1 classid 1:10 htb rate ${CEIL}kibit ceil ${CEIL}kibit prio 0 $ADSLL
tc class add dev $DEV parent 1:1 classid 1:11 htb rate 32kibit ceil ${PRIO_RATE}kibit prio 1 $ADSLL
tc class add dev $DEV parent 1:1 classid 1:12 htb rate ${BE_RATE}kibit ceil ${BE_CEIL}kibit prio 2 $ADSLL
tc class add dev $DEV parent 1:1 classid 1:13 htb rate ${BK_RATE}kibit ceil ${BE_CEIL}kibit prio 3 $ADSLL

# The calculations (still) needed here are why I 
# wanted to do this in lua first.
# all the variables - limit, depth, min, max, redflowlimit 
# are dependent on the bandwidth, but scale differently. 
# I don't think RED can be made to work on long RTTs, period...

# I'd prefer to use a pre-nat filter but that causes permutation...
# Anyway... need FP (sqrt) from lua to finish this part...

# A depth of 16 is better at low rates, but no lower. 
# I'd argue for a floor of 22 Packet aggregation suggests 
# ${DEPTH}-64.

tc qdisc add dev $DEV parent 1:11 handle 110: codel
tc qdisc add dev $DEV parent 1:12 handle 120: codel
tc qdisc add dev $DEV parent 1:13 handle 130: codel 

#tc filter add dev $DEV parent 1:0 protocol ip prio 4 u32 match u8 8 \
#fc at 1 classid 1:13
#for i in `seq 4 254`
#do
#a=`printf "tc filter add dev $DEV protocol ip parent 1:0 prio %d u32 match u8 0x%x 0x03 at 1 classid 1:13" $i $i`
#$a
#a=`printf "tc filter add dev $DEV protocol ip parent 1:0 prio %d u32 match ip tos 0x%x 0xfc classid 1:13" $i $i`
#$a
#done

# This could be a complete diffserv implementation

tc filter add dev $DEV protocol ip parent 1:0 prio 1 u32 match ip tos 0x00 0xfc classid 1:12 # CS0
tc filter add dev $DEV protocol ip parent 1:0 prio 2 u32 match ip tos 0x10 0xfc classid 1:11 # Low Delay
tc filter add dev $DEV protocol ip parent 1:0 prio 3 u32 match ip tos 0x20 0xfc classid 1:13 # CS1 Bulk
tc filter add dev $DEV protocol ip parent 1:0 prio 4 u32 match ip tos 0x88 0xfc classid 1:11 # AF41
tc filter add dev $DEV protocol ip parent 1:0 prio 5 u32 match ip tos 0x90 0xfc classid 1:11 # AF42
tc filter add dev $DEV protocol ip parent 1:0 prio 21 u32 match ip tos 0x98 0xfc classid 1:11 # AF43
tc filter add dev $DEV protocol ip parent 1:0 prio 7 u32 match ip tos 0x28 0xfc classid 1:12 # AF11
tc filter add dev $DEV protocol ip parent 1:0 prio 8 u32 match ip tos 0x30 0xfc classid 1:12 # AF12
tc filter add dev $DEV protocol ip parent 1:0 prio 9 u32 match ip tos 0x38 0xfc classid 1:13 # AF13
tc filter add dev $DEV protocol ip parent 1:0 prio 10 u32 match ip tos 0x48 0xfc classid 1:12 # AF21
tc filter add dev $DEV protocol ip parent 1:0 prio 11 u32 match ip tos 0x58 0xfc classid 1:12 # AF22
tc filter add dev $DEV protocol ip parent 1:0 prio 12 u32 match ip tos 0x58 0xfc classid 1:13 # AF23
tc filter add dev $DEV protocol ip parent 1:0 prio 13 u32 match ip tos 0x68 0xfc classid 1:12 # AF31
tc filter add dev $DEV protocol ip parent 1:0 prio 14 u32 match ip tos 0x70 0xfc classid 1:12 # AF32
tc filter add dev $DEV protocol ip parent 1:0 prio 15 u32 match ip tos 0x78 0xfc classid 1:13 # AF33

tc filter add dev $DEV protocol ip parent 1:0 prio 16 u32 match ip tos 0x40 0xfc classid 1:13 # CS2
tc filter add dev $DEV protocol ip parent 1:0 prio 17 u32 match ip tos 0x60 0xfc classid 1:13 # CS3
tc filter add dev $DEV protocol ip parent 1:0 prio 18 u32 match ip tos 0x80 0xfc classid 1:13 # CS4
tc filter add dev $DEV protocol ip parent 1:0 prio 19 u32 match ip tos 0xa0 0xfc classid 1:13 # CS5
tc filter add dev $DEV protocol ip parent 1:0 prio 9 u32 match ip tos 0xc0 0xfc classid 1:11 # CS6
tc filter add dev $DEV protocol ip parent 1:0 prio 6 u32 match ip tos 0xe0 0xfc classid 1:11 # CS7

#tc filter add dev $DEV parent 1:0 protocol ip prio 3 handle 1 fw classid 1:12
#tc filter add dev $DEV parent 1:0 protocol ip prio 4 handle 2 fw classid 1:13

# ipv6 support. Note that the handle indicates the fw mark bucket that is looked for

#tc filter add dev $DEV parent 1:0 protocol ipv6 prio 8 handle 1 fw classid 1:11
#tc filter add dev $DEV parent 1:0 protocol ipv6 prio 9 handle 2 fw classid 1:12
#tc filter add dev $DEV parent 1:0 protocol ipv6 prio 10 handle 3 fw classid 1:13

# Arp traffic

#tc filter add dev $DEV parent 1:0 protocol arp prio 7 handle 1 fw classid 1:11

ifconfig ifb0 up

# redirect all IP packets arriving in $IFACE to ifb0 

$TC filter add dev $IFACE parent ffff: protocol all prio 10 u32 \
  match u32 0 0 flowid 1:1 action mirred egress redirect dev $DEV

}

ipt_setup
egress 
ingress

# References:
# This alternate shaper attempts to go for 1/u performance in a clever way
# http://git.coverfire.com/?p=linux-qos-scripts.git;a=blob;f=src-3tos.sh;hb=HEAD

# Comments
# This does the right thing with ipv6 traffic.
# It also does not rehash with sfq skewing streams
# It also tries to leverage diffserv to some sane extent. In particular,
# the 'priority' queue is limited to 33% of the total, so EF, and IMM traffic
# cannot starve other types. The rfc suggested 30%. 30% is probably
# a lot in today's world.

# Flaws
# Many!

# Why 42?
# Lucky number.
# the sum of the number of packets here + htb + the ar71xx device driver
# ~= 50 the core number used by theorists everywhere.

