#!/bin/sh

DEV=eth2

tc qdisc del dev $DEV root 2> /dev/null
tc qdisc add dev $DEV root handle 1: hfsc default 11
tc class add dev $DEV parent 1: classid 1:1 hfsc sc rate 1000kbit ul rate 1000kbit
tc class add dev $DEV parent 1:1 classid 1:10 hfsc sc rate 500kbit ul rate 1000kbit
tc class add dev $DEV parent 1:1 classid 1:20 hfsc sc rate 500kbit ul rate 1000kbit
tc class add dev $DEV parent 1:10 classid 1:11 hfsc sc umax 1500b dmax 53ms rate 400kbit ul rate 1000kbit
tc class add dev $DEV parent 1:10 classid 1:12 hfsc sc umax 1500b dmax 30ms rate 100kbit ul rate 1000kbit 

tc qdisc add dev $DEV parent 1:11 handle 20: sfq perturb 1
tc qdisc add dev $DEV parent 1:12 handle 30: sfq perturb 1

