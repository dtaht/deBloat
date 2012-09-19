#!/bin/sh

SERVER=172.20.6.1

ping -c 65 $SERVER &
(
netperf -l60 -H$SERVER -t UDP_STREAM | tail -1 &
netperf -l60 -H$SERVER -t TCP_MAERTS | tail -1 &
netperf -l60 -H$SERVER -t TCP_STREAM | tail -1 &
netperf -l60 -H$SERVER -t TCP_MAERTS | tail -1 &
) | awk '{ print $5 }'
