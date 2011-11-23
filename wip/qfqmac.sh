#!/bin/sh
TC=~d/git/iproute2/tc/tc
IFACE=eth0
#TNETS="172.30.48.1/24 172.30.49.1/24"
TNETS="0.0.0.0/0"
#172.30.48.1/24 172.30.49.1/24"

${TC} qdisc del dev $IFACE handle 1 root
${TC} qdisc add dev $IFACE handle 1 root qfq
${TC} class add dev $IFACE parent 1: classid 1:0 qfq 
${TC} class add dev $IFACE parent 1: classid 1:1 qfq 
${TC} class add dev $IFACE parent 1: classid 1:2 qfq
${TC} class add dev $IFACE parent 1: classid 1:3 qfq
${TC} class add dev $IFACE parent 1: classid 1:4 qfq
${TC} qdisc add dev $IFACE parent 1:0 handle 10 pfifo_head_drop limit 64
${TC} qdisc add dev $IFACE parent 1:1 handle 20 pfifo_head_drop limit 64
${TC} qdisc add dev $IFACE parent 1:2 handle 30 pfifo_head_drop limit 24
${TC} qdisc add dev $IFACE parent 1:3 handle 40 pfifo_head_drop limit 24
${TC} qdisc add dev $IFACE parent 1:4 handle 50 pfifo_head_drop limit 24

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

# This matches all ip protocols and is one of three rules working

${TC} filter add dev $IFACE protocol ip parent 1: handle 3 prio 1 \
        flow hash keys proto-dst divisor 2

# And it turns out that you have to match ipv6 separately

${TC} filter add dev $IFACE protocol ipv6 parent 1: prio 2 \
	u32 match ip protocol 0 0x00 flowid 1:3

# And this is a catchall for everything else

${TC} filter add dev $IFACE protocol all parent 1: prio 100 \
	u32 match ip protocol 0 0x00 flowid 1:4

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


