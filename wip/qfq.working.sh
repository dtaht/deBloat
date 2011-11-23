#!/bin/sh

# Eric's test script

TC=~d/git/iproute2/tc/tc
DEV=eth0
RATE="rate 40Mbit"
TNETS="192.168.0.0/16"
ALLOT="allot 20000"

${TC} qdisc del dev $DEV root 2>/dev/null

${TC} qdisc add dev $DEV root handle 1: cbq avpkt 1000 rate 1000Mbit \
	bandwidth 1000Mbit
${TC} class add dev $DEV parent 1: classid 1:1 \
	est 1sec 8sec cbq allot 10000 mpu 64 \
	rate 1000Mbit prio 1 avpkt 1500 bounded

# output to test nets :  40 Mbit limit
${TC} class add dev $DEV parent 1:1 classid 1:11 \
	est 1sec 8sec cbq $ALLOT mpu 64      \
	$RATE prio 2 avpkt 1400 bounded

${TC} qdisc add dev $DEV parent 1:11 handle 11:  \
	est 1sec 8sec qfq

${TC} filter add dev $DEV protocol ip parent 11: handle 3 \
	flow hash keys proto-dst divisor 32

for i in `seq 1 32`
do
 classid=11:$(printf %x $i)
 ${TC} class add dev $DEV classid $classid est 1sec 8sec qfq 
 ${TC} qdisc add dev $DEV parent $classid est 1sec 8sec pfifo limit 30
done

for privnet in $TNETS
do
	${TC} filter add dev $DEV parent 1: protocol ip prio 100 u32 \
		match ip dst $privnet flowid 1:11
done

${TC} filter add dev $DEV parent 1: protocol ip prio 100 u32 \
	match ip protocol 0 0x00 flowid 1:1
