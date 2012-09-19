#!/bin/sh

DEV=eth2
RATE=4mbit
RATE1=2mbit
RATE2=1mbit
RATE3=1mbit
TC=~d/git/iproute/tc/tc

${TC} qdisc del dev $DEV root 2> /dev/null

${TC} qdisc add dev $DEV root handle 1: htb default 11

${TC} class add dev $DEV parent 1: classid 1:1 htb rate $RATE ceil $RATE
${TC} class add dev $DEV parent 1:1 classid 1:10 htb rate $RATE1 ceil $RATE
${TC} class add dev $DEV parent 1:1 classid 1:11 htb rate $RATE2
${TC} class add dev $DEV parent 1:1 classid 1:12 htb rate $RATE3 

${TC} qdisc add dev $DEV parent 1:10 handle 20: nfq_codel noecn quantum 1000 flows 64000
${TC} qdisc add dev $DEV parent 1:11 handle 30: nfq_codel noecn quantum 1000 flows 64000
${TC} qdisc add dev $DEV parent 1:12 handle 40: nfq_codel noecn quantum 1000 flows 64000

#${TC} filter add dev $DEV parent 1:0 protocol ip u32 \
#	ma${TC}h ip protocol 17 0xff flowid 1:12
