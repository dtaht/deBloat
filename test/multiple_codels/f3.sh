#!/bin/sh

SERVER=172.20.11.1
SERVER2=172.20.11.11

ping -c 65 $SERVER &
(
netperf -l60 -H$SERVER -t TCP_MAERTS | tail -1 &
netperf -l60 -H$SERVER -t TCP_STREAM | tail -1 &
netperf -l60 -H$SERVER -t TCP_MAERTS | tail -1 &
netperf -l60 -H$SERVER2 -t TCP_MAERTS | tail -1 &
netperf -l60 -H$SERVER2 -t TCP_STREAM | tail -1 &
netperf -l60 -H$SERVER2 -t TCP_MAERTS | tail -1 &
) | awk '{ print $5 }'
