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

# You need to jiggle these parameters

UPLINK=4000
DOWNLINK=20000

CEIL=$UPLINK
MTU=1500
ADSLL=""
# PPOE=yes

# You shouldn't need to touch anything here  

PERTURB="perturb 0" # Permutation is costly, disable
FLOWS=16000 # 

if [ -s "$PPOE" ] 
then
	OVERHEAD=40
	LINKLAYER=adsl
	ADSLL="linklayer ${LINKLAYER} overhead ${OVERHEAD}"
fi

PRIO_RATE=`expr $CEIL / 3` # Ceiling for prioirty
BE_RATE=`expr $CEIL / 6`   # Min for best effort
BK_RATE=`expr $CEIL / 9`   # Min for background
BE_CEIL=`expr $CEIL - 64`  # A little slop at the top

R2Q=""

if [ "$CEIL" -lt 1000 ]
then
	R2Q="rtq 1"
fi

ipt() {
iptables $*
ip6tables $*
}

egress() {

ipt -t mangle -F
ipt -t mangle -N QOS_MARK

ipt -t mangle -A QOS_MARK -j MARK --set-mark 0x2
# You can go further with classification but...
ipt -t mangle -A QOS_MARK -m dscp --dscp-class CS1 -j MARK --set-mark 0x3
ipt -t mangle -A QOS_MARK -m dscp --dscp-class CS6 -j MARK --set-mark 0x1
ipt -t mangle -A QOS_MARK -m dscp --dscp-class EF -j MARK --set-mark 0x1
ipt -t mangle -A QOS_MARK -m dscp --dscp-class AF42 -j MARK --set-mark 0x1
ipt -t mangle -A QOS_MARK -m tos --tos Minimize-Delay -j MARK --set-mark 0x1
ipt -t mangle -A QOS_MARK -i s+ -p tcp -m tcp --tcp-flags SYN,RST,ACK SYN -j MARK --set-mark 0x1

# Not sure if this will work. Encapsulation is a problem period
ipt -t mangle -A QOS_MARK -i vtun+ -p tcp -j MARK --set-mark 0x2 # tcp tunnels need ordering
# and it might be a good idea to do it for udp tunnels too

# Turn it on. Some sources suggest PREROUTING here

ipt -t mangle -A POSTROUTING -o $IFACE -g QOS_MARK 

# Emanating from router, do a little more optimization
# but don't bother with it too much. Not clear if the second line is needed

ipt -t mangle -A OUTPUT -p udp -m multiport --ports 123,53 -j DSCP --set-dscp-class AF42
#ipt -t mangle -A OUTPUT -o $IFACE -g QOS_MARK

# TC rules

tc qdisc del dev $IFACE root
tc qdisc add dev $IFACE root handle 1: htb ${RTQ} default 12
tc class add dev $IFACE parent 1: classid 1:1 htb rate ${CEIL}kbit ceil ${CEIL}kbit $ADSLL
tc class add dev $IFACE parent 1:1 classid 1:10 htb rate ${CEIL}kbit ceil ${CEIL}kbit prio 0 $ADSLL
tc class add dev $IFACE parent 1:1 classid 1:11 htb rate 32kbit ceil ${PRIO_RATE}kbit prio 1 $ADSLL
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

tc qdisc add dev $IFACE parent 1:11 handle 110: sfq limit 200 depth 42 flows $FLOWS \
min 3000 max 18000 probability .2 redflowlimit 32000 ${PERTURB} ecn headdrop harddrop
tc qdisc add dev $IFACE parent 1:12 handle 120: sfq limit 300 depth 42 flows $FLOWS \
min 3000 max 18000 probability .2 redflowlimit 32000 ${PERTURB} ecn headdrop harddrop
tc qdisc add dev $IFACE parent 1:13 handle 130: sfq limit 150 depth 42 flows $FLOWS \
min 3000 max 18000 probability .2 redflowlimit 32000 ${PERTURB} ecn headdrop harddrop

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
# tbd
:
}

egress 
ingress

# References:
# This shaper attempts to go for 1/u performance in a clever way
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

