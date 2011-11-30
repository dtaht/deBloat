#!/bin/sh
TC=~d/git/iproute2/tc/tc
IFACE=wlan0
BINS=256
BLIMIT=24000
GLIMIT=32
BIGDISC="red min 4500 max 9000 probability 0.01 avpkt 1000 limit 24000 burst 5 ecn"
MDISC="pfifo limit 16"
NORMDISC="pfifo limit 32"

ifconfig $IFACE txqueuelen 8192

main=10
VO=10
VI=20
BE=30
BK=40

# Watch out! There's an interaction here with 0:0x0100-6 which are special
# FIXME

${TC} qdisc del dev $IFACE handle 1 root
${TC} qdisc add dev $IFACE handle 1 root mq
${TC} qdisc add dev $IFACE parent 1:0 handle 5 qfq
${TC} qdisc add dev $IFACE parent 1:1 handle $VO qfq
${TC} qdisc add dev $IFACE parent 1:2 handle $VI qfq
${TC} qdisc add dev $IFACE parent 1:3 handle $BE qfq
${TC} qdisc add dev $IFACE parent 1:4 handle $BK qfq

# Setting all this up is high overhead so we
# setup the the default bins first

MULTICAST=`expr $BINS + 1`
DEFAULTB=`expr $BINS + 2`

mcast=`printf "%x" $MULTICAST`
def=`printf "%x" $DEFAULTB`

# Multicast is 'special' on wireless. It WEIGHS a lot

${TC} class add dev $IFACE parent $VO classid $VO:$mcast qfq
${TC} qdisc add dev $IFACE parent $VO:$mcast handle $mcast \
	$MDISC

${TC} class add dev $IFACE parent $BE classid $BE:$def qfq 
${TC} qdisc add dev $IFACE parent $BE:$def handle $def $NORMDISC 

# Match Mac addresses for multicast
# FIXME: are there other ways to get at multicast? 802.3?
# (Mis)treat multicast specially

${TC} filter add dev $IFACE protocol ip parent 10: prio 5 \
       u32 match u16 0x0100 0x0100 at -14 flowid $VO:$mcast

${TC} filter add dev $IFACE protocol ipv6 parent 10: prio 6 \
       u32 match u16 0x0100 0x0100 at -14 flowid $VO:$mcast

${TC} filter add dev $IFACE protocol arp parent 30: prio 7 \
       u32 match u16 0x0100 0x0100 at -14 flowid $VO:$mcast

# ARP?

# And this is a catchall for everything else (while we setup elsewhere)

${TC} filter add dev $IFACE protocol all parent 30: prio 999 \
	u32 match ip protocol 0 0x00 flowid $BE:$def

for j in $VO $VI $BE $BK
do
for i in `seq 0 $BINS`
do
hex=`printf "%x" $i`
${TC} class add dev $IFACE parent $j: classid $j:$hex qfq 
${TC} qdisc add dev $IFACE parent $j:$hex handle $hex $BIGDISC
done
done

for i in $VO $VI $BK $BE
do
${TC} filter add dev $IFACE protocol ip parent $i: handle 3 prio 97 \
        flow hash keys proto-dst,rxhash divisor $BINS

${TC} filter add dev $IFACE protocol ipv6 parent $i: handle 4 prio 98 \
        flow hash keys proto-dst,rxhash divisor $BINS
done

# And it turns out that you can match ipv6 separately

#${TC} filter add dev $IFACE protocol ipv6 parent 1: prio 99 \
#	u32 match ip protocol 0 0x00 flowid 1:$mcast

exit

#       src,dst,proto,proto-src,proto-dst divisor 1024 perturb 10

