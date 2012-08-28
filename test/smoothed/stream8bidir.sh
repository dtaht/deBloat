#!/bin/sh

SERVER1=172.20.11.11
SERVER2=172.20.11.1

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
