#!/bin/sh

SERVER1=192.168.10.1
SERVER2=$SERVER1

(
netperf -l 60 -H $SERVER1 -t TCP_MAERTS | tail -1 &
netperf -l 60 -H $SERVER1 -t TCP_STREAM | tail -1 &
netperf -l 60 -H $SERVER1 -t TCP_MAERTS | tail -1 &
netperf -l 60 -H $SERVER1 -t TCP_STREAM | tail -1 &

netperf -l 60 -H $SERVER2 -t TCP_MAERTS | tail -1 &
netperf -l 60 -H $SERVER2 -t TCP_STREAM | tail -1 &
netperf -l 60 -H $SERVER2 -t TCP_MAERTS | tail -1 &
netperf -l 60 -H $SERVER2 -t TCP_STREAM | tail -1 &
) | awk '{ print $5 }'
