#!/bin/sh

# This script is presently targetted to go into 
# /etc/network/ifup.d

LL=1 # go for lowest latency
ECN=1 # enable ECN

BQLLIMIT=3000 # at speeds below 100Mbit, 2 big packets is enough

[ -z "$IFACE" ] && echo error: $0 expects IFACE parameter in environment && exit 1
[ -z `which ethtool` ] && echo error: ethtool is required && exit 1
[ -z `which tc` ] && echo error: tc is required && exit 1
# FIXME see if fq_codel is available. modprobe?
# BUGS - need to detect bridges. 
#      - Need filter to distribute across mq ethernet devices
#      - needs an "undebloat" script for ifdown
#      - should probably use a lower fq_codel limit at wifi and 10Gbit

S=/sys/class/net
FQ_OPTS=""
#FQ_OPTS="FLOWS 2048 TARGET 5ms LIMIT 1000"

[ $LL -eq 1 ] && FQ_OPTS="$FQ_OPTS quantum 500"
[ $ECN -eq 1 ] && FQ_OPTS="$FQ_OPTS ecn"

# Offloads are evil in the quest for low latency
# And ethtool will abort if you attempt to turn off a
# nonexistent offload.

et() {
(
	ethtool -K $IFACE tso off
	ethtool -K $IFACE gso off
	ethtool -K $IFACE ufo off
# Presently unknown if gro/lro affect latency much
	ethtool -K $IFACE gro off
	ethtool -K $IFACE lro off
) 2> /dev/null
}

# Wifi is special in that how the queues work is pre-defined
# to be voice, video, best effort and background

wifi() {
	tc qdisc add dev $IFACE handle 1 root mq 
	tc qdisc add dev $IFACE parent 1:1 fq_codel $FQ_OPTS noecn
	tc qdisc add dev $IFACE parent 1:2 fq_codel $FQ_OPTS
	tc qdisc add dev $IFACE parent 1:3 fq_codel $FQ_OPTS
	tc qdisc add dev $IFACE parent 1:4 fq_codel $FQ_OPTS noecn
}

# Hardware mq devices are special 

mq() {
	local I=1
	tc qdisc add dev $IFACE handle 1 root mq 

	for i in $S/$IFACE/queues/tx-*
	do
		tc qdisc add dev $IFACE parent 1:$I fq_codel $FQ_OPTS
		I=`expr $I + 1`
	done
}

fq_codel() {
	tc qdisc add dev $IFACE root fq_codel $FQ_OPTS
}

fix_speed() {
local SPEED=`cat $S/$IFACE/speed` 2> /dev/null
if [ -n "$SPEED" ]
then
	if [ "$SPEED" -lt 101 ]
	then
		for I in /sys/class/net/$IFACE/queues/tx-%d/byte_queue_limits/limit_max
		do
		echo $BQLLIMIT > $I
		done
	fi
fi
}

fix_queues() {
local QUEUES=`ls -d $S/$IFACE/queues/tx-* | wc -l | awk '{print $1}'`
if [ $QUEUES -gt 1 ]
then
	if [ -x $S/$IFACE/phy80211 ] 
	then
		wifi
	else
		mq
	fi
else
	fq_codel
fi
}


tc qdisc del dev $IFACE root 2> /dev/null
[ $LL -eq 1 ] && et # for lowest latency disable offloads
fix_speed
fix_queues

exit 0

