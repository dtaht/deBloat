#!/bin/sh

NETSERVER=huchra.bufferbloat.net
#NETSERVER=huchra.bufferbloat.net
LDIR=/tmp
DUR=120

# Prime DNS
nslookup $NETSERVER > /dev/null
traceroute -n $NETSERVER >> $LDIR/traceroute

# Test three bins of the shaper 
# Also good on wireless hw queues
# against ipv4 and ipv6

for i in CS1 EF BE
do
netperf -6 -Y $i,$i -l $DUR -H $NETSERVER >> ${LDIR}/${i}_6.log &
netperf -4 -Y $i,$i -l $DUR -H $NETSERVER >> ${LDIR}/${i}.log &
done
