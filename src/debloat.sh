#!/bin/sh

[ ! -s `which ethtool` ] && echo ethtool is required && exit 1
[ ! -s `which tc` ] && echo tc is required && exit 1
# see if fq_codel is available

# Offloads are evil in the quest for low latency
ll() {
	ethtool -K $IFACE tso off gso off gro off
	ethtool -K $IFACE ufo off
}

ethernet() {

for i in /sys/class/net/$IFACE/queues/tx-*
do

done

}

wifi() {
}

