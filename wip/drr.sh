#!/bin/sh

tc qdisc add dev eth0 handle 1 root drr
tc class add dev eth0 parent 1: classid 1:1 drr 
tc class add dev eth0 parent 1: classid 1:2 drr

#       You also need to add at least one filter to classify packets.

tc filter add dev eth0 protocol all classid 1:1

#       tc qdisc add dev .. drr

#       for i in .. 1024;do
#            tc class add dev .. classid $handle:$(print %x $i)
#            tc qdisc add dev .. fifo limit 16
#       done

#       tc  filter  add  ..   protocol   ip   ..   $handle   flow   hash   keys
#       src,dst,proto,proto-src,proto-dst divisor 1024 perturb 10


