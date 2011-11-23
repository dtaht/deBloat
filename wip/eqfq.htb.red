#!/bin/sh
TC=~d/git/iproute2/tc/tc
IFACE=eth0
#TNETS="172.30.48.1/24 172.30.49.1/24"
TNETS="0.0.0.0/0"
#172.30.48.1/24 172.30.49.1/24"
BINS=256
BLIMIT=24000
GLIMIT=32
BIGDISC="red min 4500 max 9000 probability 0.01 avpkt 1000 limit 24000 burst 5 ecn"
MDISC=pfifo
NORMDISC=pfifo
UPLOAD=4mbit

ifconfig $IFACE txqueuelen 120

#tc class ... dev dev parent major:[minor] [ classid major:minor  ]  htb
#rate rate [ ceil rate ] burst bytes [ cburst bytes ] [ prio priority ]


${TC} qdisc del dev $IFACE root
${TC} qdisc add dev $IFACE root handle 1000 htb default 0
${TC} class add dev $IFACE parent 1000: classid 1001 htb \
	rate $UPLOAD burst 16k prio 1 

${TC} qdisc add dev $IFACE handle 1 parent 1001 est 1sec 8sec qfq

# Setting all this up is high overhead so we
# setup the the default bins first

MULTICAST=`expr $BINS + 1`
DEFAULTB=`expr $BINS + 2`

mcast=`printf "%x" $MULTCAST`
def=`printf "%x" $DEFAULTB`

${TC} class add dev $IFACE parent 1: classid 1:$mcast qfq 
${TC} qdisc add dev $IFACE parent 1:$mcast handle $mcast \
	$MDISC limit 16

${TC} class add dev $IFACE parent 1: classid 1:$def qfq 
${TC} qdisc add dev $IFACE parent 1:$def handle $def \
	$NORMDISC limit 16

${TC} filter add dev $IFACE protocol ip parent 1: prio 5 \
       u32 match u16 0x0100 0x0100 at -14 flowid 1:$mcast

${TC} filter add dev $IFACE protocol ipv6 parent 1: prio 6 \
       u32 match u16 0x0100 0x0100 at -14 flowid 1:$mcast

# Fixme, filter the rest of the multicast out...

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

${TC} filter add dev $IFACE protocol ip parent 1: handle 3 prio 97 \
        flow hash keys proto-dst divisor $BINS

${TC} filter add dev $IFACE protocol ipv6 parent 1: handle 4 prio 98 \
        flow hash keys proto-dst divisor $BINS

# And it turns out that you can match ipv6 separately

#${TC} filter add dev $IFACE protocol ipv6 parent 1: prio 99 \
#	u32 match ip protocol 0 0x00 flowid 1:$mcast

exit

${TC} filter add dev $IFACE protocol ip parent 1: prio 6 \
       u32 match u16 0xFFFe 0xffff at -12 flowid 1:3

${TC} filter add dev $IFACE protocol ip parent 1: prio 6 \
       u32 match u16 0x0001 0xffff at -12 flowid 1:4

${TC} filter add dev $IFACE protocol 802 parent 1: prio 7 \
       u32 match u16 0xFFFe 0xffff at 0 flowid 1:3

${TC} filter add dev $IFACE protocol 802 parent 1: prio 7 \
       u32 match u16 0x0001 0xffff at 0 flowid 1:4

${TC} filter add dev $IFACE protocol 802_3 parent 1: prio 3 \
       u32 match u16 0xFFFe 0xffff at 0 flowid 1:3

${TC} filter add dev $IFACE protocol 802_3 parent 1: prio 3 \
       u32 match u16 0x0001 0xffff at 0 flowid 1:4

${TC} filter add dev $IFACE protocol 0x0806 parent 1: prio 11 \
	u32 match u32 0 0 flowid 1:2

# None of the above rules work. Actually the 802_3 rule 
# Seemed to work.


exit 0

for privnet in $TNETS
do
        ${TC} filter add dev $IFACE parent 1: protocol ip prio 100 u32 \
                match ip dst $privnet flowid 1:0
done



#${TC} filter add dev $IFACE parent 1: prio 10 protocol 0x0806 u32

#       You also need to add at least one filter to classify packets.


#       ${TC} qdisc add dev .. qfq

#       for i in .. 1024;do
#            ${TC} class add dev .. classid $handle:$(print %x $i)
#            ${TC} qdisc add dev .. fifo limit 16
#       done

#       ${TC}  filter  add  ..   protocol   ip   ..   $handle   flow   hash   keys
#       src,dst,proto,proto-src,proto-dst divisor 1024 perturb 10


