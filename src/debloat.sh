#!/bin/bash
# debloat.sh -	improves network latency by reducing excessive buffering
#		and offloads on common devices and enabling fq_codel.
# Copyright 2012 M D Taht. Released into the public domain.

# This script is presently targetted to go into
# /etc/network/ifup.d on debian derived systems

[[ "$IFACE" == "lo" ]] && exit 0

LL=1 # go for lowest latency
ECN=1 # enable ECN
BQLLIMIT100=3000 # at speeds below 100Mbit, 2 big packets is enough
BQLLIMIT10=1514 # at speeds below 10Mbit, 1 big packet is enough.
		# Actually it would be nice to go to just one packet
QDISC=fq_codel # There are multiple variants of fq_codel in testing
FQ_LIMIT="" # the default 10000 packet limit mucks with slow start at speeds
            # at 1Gbit and below. Somewhat arbitrary figures selected.

[ -z "$IFACE" ] && echo error: $0 expects IFACE parameter in environment && exit 1
[ -z `which ethtool` ] && echo error: ethtool is required && exit 1
[ -z `which tc` ] && echo error: tc is required && exit 1
# FIXME see if $QDISC is available. modprobe?

# BUGS - need to detect bridges.
#      - Need filter to distribute across mq ethernet devices
#      - needs an "undebloat" script for ifdown to restore BQL autotuning

S=/sys/class/net
FQ_OPTS=""
#FQ_OPTS="FLOWS 2048 TARGET 5ms"

[ $LL -eq 1 ] && FQ_OPTS="$FQ_OPTS quantum 500"
[ $ECN -eq 1 ] && FQ_OPTS="$FQ_OPTS ecn"

FLOW_KEYS="src,dst,proto,proto-src,proto-dst"
# For 5-tuple (flow) fairness when the same device is performing NAT
#FLOW_KEYS="nfct-src,nfct-dst,nfct-proto,nfct-proto-src,nfct-proto-dst"


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
	tc qdisc add dev $IFACE parent 1:1 $QDISC $FQ_OPTS noecn
	tc qdisc add dev $IFACE parent 1:2 $QDISC $FQ_OPTS
	tc qdisc add dev $IFACE parent 1:3 $QDISC $FQ_OPTS
	tc qdisc add dev $IFACE parent 1:4 $QDISC $FQ_OPTS noecn
}

# Hardware mq ethernet devs are special and need some sort of filter
# attached to actually use in most cases. FIXME. (see tg3)

mq() {
	local I=1
	tc qdisc add dev $IFACE handle 1 root mq

	for i in $S/$IFACE/queues/tx-*
	do
		tc qdisc add dev $IFACE parent 1:$(printf "%x" $I) $QDISC $FQ_OPTS
		I=`expr $I + 1`
	done
	I=`expr $I - 1`
	tc filter add dev $IFACE prio 1 protocol ip parent 1: handle 100 \
		flow hash keys ${FLOW_KEYS} divisor $I baseclass 1:1
}

fq_codel() {
	tc qdisc add dev $IFACE root $QDISC $FQ_OPTS $FQ_LIMIT
}

fix_speed() {
local SPEED=`cat $S/$IFACE/speed` 2> /dev/null
if [ -n "$SPEED" ]
then
	[ "$SPEED" = 4294967295 ] && echo "no ethernet speed selected. debloat estimate will be WRONG"
	[ "$SPEED" -lt 1001 ] && FQ_LIMIT="limit 1200"
	if [ "$SPEED" -lt 101 ]
	then
	[ $LL -eq 1 ] && et # for lowest latency disable offloads
	BQLLIMIT=$BQLLIMIT100
	FQ_LIMIT="limit 800"
	[ "$SPEED" -lt 11 ] && BQLLIMIT=$BQLLIMIT10 && FQ_LIMIT="limit 400"
	for I in /sys/class/net/$IFACE/queues/tx-*/byte_queue_limits/limit_max
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
fix_speed
fix_queues

exit 0
