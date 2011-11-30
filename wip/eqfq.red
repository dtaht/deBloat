#!/bin/sh
# This is the closest I have yet come to making 100Mbit ethernet
# work well with minimal interstream latencies.
# It DOES run at line rate.

# Requires BQL in order to work right + a tweak or two

TC=~d/git/iproute2/tc/tc
TXQUEUELEN=1000
IFACE=eth0
BINS=256
BLIMIT=24000
GLIMIT=32
BIGDISC="red min 4500 max 9000 probability 0.01 avpkt 1000 limit 24000 burst 5 ecn"
MDISC=pfifo
NORMDISC=pfifo

# FIXME: We should try to keep at least 2 packets in each bin
# So we need to set txqueuelen more appropriately

${TC} qdisc del dev $IFACE handle 1 root
ifconfig $IFACE txqueuelen $TXQUEUELEN
${TC} qdisc add dev $IFACE handle 1 root qfq

# Setting all this up is high overhead so we
# setup the the default bins first

MULTICAST=`expr $BINS + 1`
DEFAULTB=`expr $BINS + 2`

mcast=`printf "%x" $MULTCAST`
def=`printf "%x" $DEFAULTB`

${TC} class add dev $IFACE parent 1: classid 1:$mcast qfq 
${TC} qdisc add dev $IFACE parent 1:$mcast handle $mcast \
	$MDISC limit $GLIMIT

${TC} class add dev $IFACE parent 1: classid 1:$def qfq 
${TC} qdisc add dev $IFACE parent 1:$def handle $def \
	$NORMDISC limit $GLIMIT

# Schedule all multicast traffic in one bin

${TC} filter add dev $IFACE protocol ip parent 1: prio 5 \
       u32 match u16 0x0100 0x0100 at -14 flowid 1:$mcast

${TC} filter add dev $IFACE protocol ipv6 parent 1: prio 6 \
       u32 match u16 0x0100 0x0100 at -14 flowid 1:$mcast

# Do I need to match arp?

# And this is a catchall for everything else

${TC} filter add dev $IFACE protocol all parent 1: prio 999 \
	u32 match ip protocol 0 0x00 flowid 1:$def

for i in `seq 0 $BINS`
do
hex=`printf "%x" $i`
${TC} class add dev $IFACE parent 1: classid 1:$hex qfq 
${TC} qdisc add dev $IFACE parent 1:$hex handle $hex $BIGDISC
done

# This matches all ip protocols and is one of three rules working

${TC} filter add dev $IFACE protocol ip parent 1: handle 3 prio 96 \
        flow hash keys proto-dst,rxhash divisor $BINS

${TC} filter add dev $IFACE protocol ipv6 parent 1: handle 4 prio 97 \
        flow hash keys proto-dst,rxhash divisor $BINS

# Fixme for vlans??

# And it turns out that you can match ipv6 separately

#${TC} filter add dev $IFACE protocol ipv6 parent 1: prio 99 \
#	u32 match ip protocol 0 0x00 flowid 1:$mcast

exit

# 	Probably need a more robust filter above.
#       src,dst,proto,proto-src,proto-dst divisor 1024 perturb 10


