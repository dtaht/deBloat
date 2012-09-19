#!/bin/sh

SERVER=172.20.11.1

(
netperf -l60 -H$SERVER -t UDP_STREAM | tail -1 &
netperf -l60 -H$SERVER -t UDP_STREAM | tail -1 &
netperf -l60 -H$SERVER -t UDP_STREAM | tail -1 &
netperf -l60 -H$SERVER -t UDP_STREAM | tail -1 &
) | awk '{ print $5 }'
