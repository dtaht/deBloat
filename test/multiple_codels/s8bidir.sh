#!/bin/sh

RUNLOG=codel
DUR=60

SERVER1=172.20.11.11
SERVER2=172.20.11.1
SERVER3=172.20.6.1


(
netperf -l $DUR -H $SERVER1 -t TCP_MAERTS | tail -1 &
netperf -l $DUR -H $SERVER1 -t TCP_STREAM | tail -1 &
netperf -l $DUR -H $SERVER1 -t TCP_MAERTS | tail -1 &
netperf -l $DUR -H $SERVER1 -t TCP_STREAM | tail -1 &

netperf -l $DUR -H $SERVER2 -t TCP_MAERTS | tail -1 &
netperf -l $DUR -H $SERVER2 -t TCP_STREAM | tail -1 &
netperf -l $DUR -H $SERVER2 -t TCP_MAERTS | tail -1 &
netperf -l $DUR -H $SERVER2 -t TCP_STREAM | tail -1 &
) | awk '{ print $5 }' > ${RUNLOG}.netperf &

fping -C 1000 -b 240 -B1.0 -p 10 -i 10 $SERVER1 $SERVER2 $SERVER3 > /dev/null 2> ${RUNLOG}.ping

wait

