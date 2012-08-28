#!/bin/sh

DEV=eth2
RATE=4mbit
RATE1=2mbit
RATE2=1mbit
RATE3=1mbit

tc qdisc del dev $DEV root 2> /dev/null

tc qdisc add dev $DEV root handle 1: htb default 11

tc class add dev $DEV parent 1: classid 1:1 htb rate $RATE ceil $RATE
tc class add dev $DEV parent 1:1 classid 1:10 htb rate $RATE1 ceil $RATE
tc class add dev $DEV parent 1:1 classid 1:11 htb rate $RATE2
tc class add dev $DEV parent 1:1 classid 1:12 htb rate $RATE3 

tc qdisc add dev $DEV parent 1:10 handle 20: pfifo_fast # codel noecn # quantum 256
tc qdisc add dev $DEV parent 1:11 handle 30: pfifo_fast # codel noecn # quantum 256
tc qdisc add dev $DEV parent 1:12 handle 40: pfifo_fast # codel noecn # quantum 256

tc filter add dev $DEV parent 1:0 protocol ip u32 \
	match ip protocol 17 0xff flowid 1:12
