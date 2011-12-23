#!/bin/sh

# Hello, all.  I have an experimental HFSC setup with three leaf classes
# each with SFQ as the final qdisc.  One queue is for ssh on port 822, one
# is for tcp traffic on port 443, the third is the default.

# If I flood the 443 queue with netcat, my ssh sessions are responsive and
# my continuous ping shows a round trip time of around 50ms in keeping
# with my netem settings.

# However, if I flood the default queue with netcat on port 80, ssh is
# still responsive but my ping round trip times shoot up over 3000ms.

# I thought it might be the bufferbloat phenomenon so I reduced the
# txqueuelen on both sides of the ping to 0.  Both sides use old 10BaseT
# NICs and have no ring buffer.  I also set the SFQ limit on the default
# queue to 2 just in case.  Still no difference.

# The default queue is dequeuing at roughly 400 kbits which matches my
# HFSC configuration.  A full sized packet should take 30 ms to pass at
# that rate ((1514 * 8)/400,000) so, if I am round robining the queues, I
# would expect latency on a default sized ping to be only 30 ms plus the
# netem delay.
MODPROBE=`which modprobe`

# Where might this 3000 ms delay be coming from?
 IFACE=eth0
 SCHEDULERS="ifb sch_netem sch_hfsc sch_ingress cls_u32 cls_basic cls_flow cls_fw"
 for i in $SCHEDULERS
 do
    $MODPROBE $i
 done

# Here is the rule set:
(
tc qdisc del dev $IFACE root
tc qdisc del dev $IFACE ingress
tc qdisc del dev ifb0 root
tc qdisc del dev ifb0 ingres
tc qdisc del dev ifb1 root
tc qdisc del dev ifb1 ingress
) 2> /dev/null
tc qdisc add dev $IFACE root handle 1: hfsc default 20
tc class add dev $IFACE parent 1: classid 1:1 hfsc sc rate 1490kbit ul rate 1490kbit
tc class add dev $IFACE parent 1:1 classid 1:20 hfsc rt rate 400kbit ls rate 200kbit
tc qdisc add dev $IFACE parent 1:20 handle 1201 sfq perturb 10
tc class add dev $IFACE parent 1:1 classid 1:10 hfsc rt umax 16kbit dmax 50ms rate 200kbit ls rate 1000kbit
tc qdisc add dev $IFACE parent 1:10 handle 1101 sfq perturb 60
tc class add dev $IFACE parent 1:1 classid 1:30 hfsc rt umax 1514b dmax 20ms rate 20kbit
tc qdisc add dev $IFACE parent 1:30 handle 1301 sfq perturb 60
iptables -t mangle -A POSTROUTING -p 6 --syn --dport 443 -j CONNMARK --set-mark 0x10
iptables -t mangle -A PREROUTING -p 6 --syn --dport 822 -j CONNMARK --set-mark 0x11
iptables -t mangle -A POSTROUTING -o $IFACE -p 6 -j CONNMARK --restore-mark
ifconfig ifb0 up
ifconfig ifb1 up
tc filter add dev $IFACE parent 1:0 protocol ip prio 1 handle 0x11 fw flowid 1:30 action mirred egress redirect dev ifb1
tc filter add dev $IFACE parent 1:0 protocol ip prio 1 handle 0x10 fw flowid 1:10 action mirred egress redirect dev ifb1
tc filter add dev $IFACE parent 1:0 protocol ip prio 2 u32 match u32 0 0 flowid 1:20 action mirred egress redirect dev ifb1
tc qdisc add dev $IFACE ingress
tc filter add dev $IFACE parent ffff: protocol ip prio 50 u32 match u32 0 0 action mirred egress redirect dev ifb0
tc qdisc add dev ifb0 root handle 1: hfsc default 20
tc class add dev ifb0 parent 1: classid 1:1 hfsc sc rate 1490kbit ul rate 1490kbit
tc class add dev ifb0 parent 1:1 classid 1:20 hfsc rt rate 400kbit ls rate 200kbit
tc qdisc add dev ifb0 parent 1:20 handle 1201 netem delay 25ms 5ms distribution normal loss 0.1% 30%
tc class add dev ifb0 parent 1:1 classid 1:10 hfsc rt umax 16kbit dmax 50ms rate 200kbit ls rate 1000kbit
tc qdisc add dev ifb0 parent 1:10 handle 1101 netem delay 25ms 5ms distribution normal loss 0.1% 30%
tc class add dev ifb0 parent 1:1 classid 1:30 hfsc rt umax 1514b dmax 20ms rate 20kbit
tc qdisc add dev ifb0 parent 1:30 handle 1301 netem delay 25ms 5ms distribution normal loss 0.1% 30%
tc filter add dev ifb0 parent 1:0 protocol ip prio 1 handle 6: u32 divisor 1
tc filter add dev ifb0 parent 1:0 protocol ip prio 1 u32 match ip protocol 6 0xff link 6: offset at 0 mask 0x0f00 shift 6 plus 0 eat
tc filter add dev ifb0 parent 1:0 protocol ip prio 1 u32 ht 6:0 match tcp src 443 0x00ff flowid 1:10
tc filter add dev ifb0 parent 1:0 protocol ip prio 1 u32 ht 6:0 match tcp dst 822 0xff00 flowid 1:30
tc qdisc add dev ifb1 root handle 2 netem delay 25ms 5ms distribution normal loss 0.1% 30%
