#!/bin/sh
# Compared to the complexity that debloat had become
# This cleanly shows means of going from diffserv marking
# to prioritization
# Routed traffic

CEIL=4000
PRIO_RATE=`expr $CEIL / 66`
BE_RATE=`expr $CEIL / 66`
BK_RATE=`expr $CEIL / 90`
BE_CEIL=`expr $CEIL - 64`

ipt() {
iptables $*
ip6tables $*
}

ipt -t mangle -F
ipt -t mangle -N QOS_MARK

ipt -t mangle -A QOS_MARK -j MARK --set-mark 0x2
ipt -t mangle -A QOS_MARK -m dscp --dscp-class CS1 -j MARK --set-mark 0x3
ipt -t mangle -A QOS_MARK -m dscp --dscp-class CS6 -j MARK --set-mark 0x1
ipt -t mangle -A QOS_MARK -m dscp --dscp-class EF -j MARK --set-mark 0x1
ipt -t mangle -A QOS_MARK -m dscp --dscp-class AF42 -j MARK --set-mark 0x1
ipt -t mangle -A QOS_MARK -m tos --tos Minimize-Delay -j MARK --set-mark 0x1
ipt -t mangle -A QOS_MARK -i s+ -p tcp -m tcp --tcp-flags SYN,RST,ACK SYN -j MARK --set-mark 0x1

# Not sure if this will work. Encapsulation is a problem period
ipt -t mangle -A QOS_MARK -i vtun+ -p tcp -j MARK --set-mark 0x2 # tcp tunnels need ordering
# and it might be a good idea to do it for udp tunnels too

# Eminating from router

ipt -t mangle -A POSTROUTING -o $IFACE -g QOS_MARK 

# Eminating from router, do a little more optimization
# but don't bother with it too much

ipt -t mangle -A OUTPUT -p udp -m multiport --ports 123,53 -j DSCP --set-dscp-class AF42
ipt -t mangle -A OUTPUT -o $IFACE -g QOS_MARK

# TC rules

tc qdisc del dev $IFACE root
tc qdisc add dev $IFACE root handle 1: htb default 12
tc class add dev $IFACE parent 1: classid 1:1 htb rate ${CEIL}kbit ceil ${CEIL}kbit
tc class add dev $IFACE parent 1:1 classid 1:10 htb rate ${CEIL}kbit ceil ${CEIL}kbit prio 0
tc class add dev $IFACE parent 1:1 classid 1:11 htb rate 32kbit ceil ${PRIO_RATE}kbit prio 1
tc class add dev $IFACE parent 1:1 classid 1:12 htb rate ${BE_RATE}kbit ceil ${BE_CEIL}kbit prio 2
tc class add dev $IFACE parent 1:1 classid 1:13 htb rate ${BK_RATE}kbit ceil ${CEIL}kbit prio 2

tc qdisc add dev $IFACE parent 1:11 handle 110: sfq limit 200 depth 42 flows 2000 \
min 3028 max 18000 probability .2 redflowlimit 32000 ecn headdrop
tc qdisc add dev $IFACE parent 1:12 handle 120: sfq limit 300 depth 42 flows 2000 \
min 3000 max 18000 probability .2 redflowlimit 32000 ecn headdrop
tc qdisc add dev $IFACE parent 1:13 handle 130: sfq limit 150 depth 42 flows 8000 \
min 3000 max 18000 probability .2 redflowlimit 32000 ecn headdrop

tc filter add dev $IFACE parent 1:0 protocol ip prio 1 handle 1 fw classid 1:11
tc filter add dev $IFACE parent 1:0 protocol ip prio 2 handle 2 fw classid 1:12
tc filter add dev $IFACE parent 1:0 protocol ip prio 3 handle 3 fw classid 1:13

# ipv6 support. Note that the handle indicates the fw mark bucket that is looked for

tc filter add dev $IFACE parent 1:0 protocol ipv6 prio 4 handle 1 fw classid 1:11
tc filter add dev $IFACE parent 1:0 protocol ipv6 prio 5 handle 2 fw classid 1:12
tc filter add dev $IFACE parent 1:0 protocol ipv6 prio 6 handle 3 fw classid 1:13

