#!/bin/sh

WIRELESS=wlan0

IFACE=$WIRELESS ./staqfq
./classify.lua > /tmp/runit.sh
sh -x /tmp/runit.sh 2> /dev/null

iptables -o $WIRELESS -t mangle -A POSTROUTING -j D_CLASSIFIER
# iptables -o $WIRELESS -t mangle -A POSTROUTING -j W80211e
iptables -o $WIRELESS -t mangle -A POSTROUTING -j SCH_MD

