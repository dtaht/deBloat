#!/usr/bin/lua
-- bittorrent buster
-- This does QFQ across machines, and then QFQ inside each machine's stream

TCPROG="~d/git/iproute2/tc/tc"
-- TC = io.open ("/dev/null", w)

BATCH=1
IFACE=eth0
MACHINES=8
BINS=1024 -- at 16 bins it goes boom for some reason with default txqueuelen
LIMIT=64
DEC_UPLINK=100000
UPLINK=math.integer(DEC_UPLINK/1000*1024) -- 4Mbit
MTU=1500

-- Optimize for ping?

PINGTOP=0
PINGCLASS=0

BIGQDISC="pfifo limit $LIMIT"
--BIGQDISC="red min 1500 max 4500 probability 0.02 avpkt 800 limit 16000 burst 5 ecn"
BASE=40

-- Yes, virginia, you actually need a txqueuelen
-- this long, unless you want to start tail dropping
-- at the queue itself. 

TXQUEUELEN=BINS * MACHINES * LIMIT

-- But Linux seems to get buggy at > 1000
-- And this of course induces starvation problems

if TXQUEUELEN > 1000 then TXQUEUELEN=1000 end

TC = io.popen (TCPROG, w)
print(string.format("qdisc del dev %s root\n",IFACE))

ifconfig %s txqueuelen $TXQUEUELEN 
modprobe sch_htb
modprobe sch_sfq

(
print(string.format( "qdisc add dev %s root handle 1: htb default 20\n", IFACE))

-- shape everything at $UPLINK speed - this prevents huge queues in your
-- DSL modem which destroy latency:

BURST=MTUb
print(string.format( "class add dev %s parent 1: classid 1:1 htb rate UPLINKkbit burst BURST\n", IFACE))))

-- high prio class 1:10:

print(string.format( "class add dev %s parent 1:1 classid 1:10 htb rate UPLINKkbit \
   burst BURST prio 1\n", IFACE))

-- bulk & default class 1:20 - gets slightly less traffic,
-- and a lower priority:

print(string.format( "class add dev %s parent 1:1 classid 1:20 htb rate $((94*$UPLINK/100))kbit \
   burst BURST prio 2\n", IFACE))

print(string.format( "class add dev %s parent 1:1 classid 1:30 htb rate $((8*$UPLINK/10))kbit \
   burst BURST prio 2\n", IFACE))

-- Two get Stochastic Fairness:
print(string.format( "qdisc add dev %s parent 1:10 handle 10: sfq perturb 10\n", IFACE))
print(string.format( "qdisc add dev %s parent 1:30 handle 30: sfq perturb 10\n", IFACE))

-- ICMP (ip protocol 1) in the interactive class 1:10 so we
-- can do measurements & impress our friends:
[ $PINGTOP = 1 ] && print(string.format( "filter add dev %s parent 1:0 protocol ip prio 10 u32 \
       match ip protocol 1 0xff flowid 1:10\n", IFACE))

-- And then we go nuts with QFQ

print(string.format( "qdisc add dev %s parent 1:20 handle BASE qfq\n", IFACE))

-- Setting all this up is high overhead so lets
-- setup the the default bins first

MULTICAST=`expr $MACHINES + 1`
DEFAULTB=`expr $MACHINES + 2`

print(string.format( "class add dev %s parent BASE classid BASE:%x qfq\n", IFACE, MULTICAST))
print(string.format( "qdisc add dev %s parent BASE:%x handle %x $BIGQDISC\n", IFACE, MULTICAST))

print(string.format( "class add dev %s parent BASE: classid BASE:%x qfq\n", IFACE, DEFAULTB))
print(string.format( "qdisc add dev %s parent BASE:%x handle %x $BIGQDISC\n", IFACE, DEFAULTB, DEFAULTB))

-- This is a catchall for everything while we setup

print(string.format( "filter add dev %s protocol all parent BASE: \
        prio 999 u32 match ip protocol 0 0x00 flowid BASE:%x\n", IFACE)) $DEFAULTB

-- Schedule all multicast/broadcast traffic in one bin
-- Multicast and broadcast are basically a 'machine', a very slow,
-- weird one.

prio=4
print(string.format( "filter add dev %s protocol 802_3 parent BASE: prio %d \
        u32 match u16 0x0100 0x0100 at 0 flowid BASE:%x\n", IFACE,proto,prio,MULTICAST
for proto in arp ip ipv6
do
prio=$(($prio+1))
print(string.format( "filter add dev %s protocol %s parent BASE: prio %d \
       u32 match u16 0x0100 0x0100 at -14 flowid BASE:%x\n", IFACE)) $proto $prio $MULTICAST
done


-- Setup the per machine classes
MACHSUBC=`expr $MACHINES + 3`
MACHCLASS=`expr $MACHSUBC '*' 4`
MACHSUBC=`expr $MACHSUBC '*' 2`
FILTERS=10
MACHSUBCX=`print(string.format( "%x" $MACHSUBC`
MACHCLASSX=`print(string.format( "%x" $MACHCLASS`
t=`expr $BINS + 1`
t1=`expr $BINS + 3`

for i in `seq 0 $MACHINES`
do
MACHSUBC=`expr $MACHSUBC + 1`
MACHCLASS=`expr $i + $MACHCLASS`
MACHSUBCX=`print(string.format( "%x" $MACHSUBC`
MACHCLASSX=`print(string.format( "%x" $MACHCLASS`

print(string.format( "class add dev %s parent BASE: classid BASE:%x qfq\n", IFACE)) $i
print(string.format( "qdisc add dev %s parent BASE:%x handle MACHSUBCX qfq\n", IFACE)) $i
for b in `seq 0 $BINS`
do
	print(string.format( "class add dev %s parent MACHSUBCX: classid MACHSUBCX:%x qfq\n", IFACE)) $b
	print(string.format( "qdisc add dev %s parent MACHSUBCX:%x $BIGQDISC\n", IFACE)) $b
done

-- Create some special bins for other stuff

for b in `seq $t $t1`
do
	print(string.format( "class add dev %s parent MACHSUBCX: classid MACHSUBCX:%x qfq\n", IFACE)) $b
	print(string.format( "qdisc add dev %s parent MACHSUBCX:%x $BIGQDISC\n", IFACE)) $b
done

-- Add stream filters to the per machine qdiscs (they won't be active yet)
-- A different filter is needed for NAT outgoing interface

FILTERS=`expr $FILTERS + 1`
print(string.format( "filter add dev %s protocol ip parent MACHSUBCX: \
	handle $FILTERS prio 97 flow hash keys proto-src,rxhash divisor $BINS\n", IFACE))

FILTERS=`expr $FILTERS + 1`
print(string.format( "filter add dev %s protocol ipv6 parent MACHSUBCX: \
	handle $FILTERS prio 98 flow hash keys proto-src,rxhash divisor $BINS\n", IFACE))

-- ICMP (ip protocol 1) in the default class
-- can do measurements & impress our friends:
print(string.format( "filter add dev %s parent MACHSUBCX: protocol ip prio 1 u32 \
        match ip protocol 1 0xff flowid MACHSUBCX:%x\n", IFACE)) $b

-- And make ABSOLUTELY sure we capture everything we missed with the filters
--FILTERS=`expr $FILTERS + 1`
--print(string.format( "filter add dev %s protocol all parent MACHSUBCX: \
--       handle FILTERS prio 999 u32 match ip protocol 0 0x00 \
--       flowid $MACHSUBC:$def

done

-- And kick everything into action

FILTERS=`expr $FILTERS + 1`

-- Now, if you are testing from one machine, you really want proto-src
-- But for deployment, you want the pre-nat source

print(string.format( "filter add dev %s protocol ip parent BASE: handle $FILTERS  \
        prio 97 flow hash keys src divisor $MACHINES\n", IFACE))

FILTERS=`expr $FILTERS + 1`

print(string.format( "filter add dev %s protocol ipv6 parent BASE: handle $FILTERS \
        prio 98 flow hash keys src divisor $MACHINES\n", IFACE))

) | TC TCOPTS

-- Walla!

