#!/usr/bin/lua

require "ceroenv"

local env = ceroenv.env
local sf = string.format

iface = "wlan0"
-- iface = assert(env.IFACE)

if (iface == nil) then 
   usage("Error: The IFACE environment variable must be set")
end

-- env.TC="~d/git/iproute2/tc/tc -b"

print(ceroenv.env["QMODEL"])

BINS=512

-- You shouldn't need to touch anything after this line

-- env.QMODEL='qfq'
-- env.PREREQS = { 'sch_qfq', 'cls_u32', 'cls_flow' }

-- require("qmodel:qfq")

MULTICAST=BINS+1
DEFAULTB=BINS+2

-- QFQ: Create a bin attached to the parent class

local function cb(base,bin,disc)
   ca("parent %x classid %x:%x qfq",base,base,bin)
   qa("parent %x:%x %s",base,bin,disc)
end

-- FIXME: It would be nice to have a cleaner way to match all multicast

local function fa_mcast(parent) 
   fa("protocol ip parent %x: prio 5 u32 match u8 0x01 0x01 at -14 flowid %x:%x",parent,parent,MULTICAST)
   fa("protocol ipv6 parent %x: prio 6 u32 match u8 0x01 0x01 at -14 flowid %x:%x",parent,parent,MULTICAST)
   fa("protocol arp parent %x: prio 7 u32 match u8 0x01 0x01 at -14 flowid %x:%x",parent,parent,MULTICAST)
end

local function fa_defb(parent) 
   fa("protocol all parent %x: prio 999 u32 match ip protocol 0 0x00 flowid %x:%x",parent,parent,DEFAULTB)
end

-- FIXME: This needs a correct hash for natted sources when NATTED=y and ipv6

local function fa_bins(parent)
   if env.NATTED == 'y' then
      fa("protocol ipv6 parent %x: handle 3 prio 94 flow hash keys proto-dst,rxhash divisor %d",parent,BINS)
      fa("protocol all parent %x: handle 3 prio 97 flow hash keys proto-dst,nfct-src divisor %d",parent,BINS)
   else
      fa("protocol all parent %x: handle 3 prio 97 flow hash keys proto-dst,rxhash divisor %d",parent,BINS)
   end
end

local function q_bins(parent)
   for i=0,BINS
   do
      ca("parent %x: classid %x:%x qfq",parent,parent,i) 
      qa("parent %x:%x %s",parent,i,BIGDISC)
   end
end

-- FIXME: add HTB rate limiter support for a hm gateway
-- What we want are various models expressed object orientedly
-- so we can tie them together eventually

local function model_qfq_pfifo_fast(base)
   cb(base,MULTICAST,MDISC)
   cb(base,DEFAULTB,NORMDISC)
   fa_defb(base)
   fa_mcast(base); 
   q_bins(base);
   fa_bins(base); 
end

local function model_sfq(base)
   qa("parent %x sfq",base)
end

-- Wireless devices are multi-queued
-- recursion would be better and if we can get away from globals
-- we can make it possible to do red, etc

local function wireless()
   if QMODEL == "qfq" then   
      VO=0x10; VI=0x20; BE=0x30; BK=0x40
      local QUEUES = { BE, VO, VI, BK }
      qa("handle 1 root mq")
      qa("parent 1:1 handle %x qfq",VO)
      qa("parent 1:2 handle %x qfq",VI)
      qa("parent 1:3 handle %x qfq",BE)
      qa("parent 1:4 handle %x qfq",BK)
      
      -- FIXME: We must get ALL multicast out of the other queues
      -- and into the VO queue. Always. Somehow.-
      
      for i,v in ipairs(QUEUES) do
	 model_qfq_pfifo_fast(v)
      end
      
   elseif QMODEL == "sfq" then
      qa("handle 1 root mq")
   for i=1,4 do
      model_sfq("1:" ..  i)
   end
end
end

local function ethernet()
   ethernet_setup(iface)
   if QMODEL == "qfq" then
      qa("handle %x root qfq",10)
      model_qfq_pfifo_fast(10)
   elseif QMODEL == "sfq" then
      qa("handle %x root sfq",10)
   end
end

local function usage(s)
   o=[[
Use of the QFQ qdisc for ethernet and wireless (for comparison, also
uses SFQ)

This script expects to be run in /etc/network/if-pre-up.d To run it
manually, do a IFACE=yournetworkcard ./this_script For NATTED
interfaces, use a NATTED=y for a better filter

STA_QFQ currently requires a new version of tc.  Build a version and
stick it somewhere and change this to suit

TC="/usr/bin/less"

QFQ can handle up to 32k bins whether you are willing to wait for them
to be generated is a better question how this interacts with
bittorrent etc is also a good question. 512 is 4x as many bins as SFQ.

I have tested as many as 2048 bins, only to run out of kernel memory
at 32000. 

Byte Queue Limits is supposed to have a rate limiter that works. It
doesn't, quite.  This seems to be the best compromise for 100Mbit I
have tried pfifo_drop_head and RED here.  both had bugs until
recently. And linux RED, being byte oriented, is just not good.
pfifo_drop_head was 'interesting' and I may return to it.

Obviously calculating a sane per-queue packet limit is an issue, too.
iw10 requires a minimum of 10, and more likely 12 (fin, close) so...
We arbitrarily double that, wave hands.  I almost never see packet
drop with 24, which is far, far better than 1000.  might need to be
larger on gigE+

We maltreat multicast especially. When handed to a load balancing filter
based on IPs, multicast addresses are all over the map.  It would be
trivial to do a DOS with this multi-bin setup So we toss all multicast
into a single bin all it's own.

You can do tricks with the DEFAULTB concept, creating a filter to
optimize for ping, for example, which makes tests reproducable Another
example would be to set aside bins for voip or dns, etc. Still, it's
saner to just let the filter do all the work of finding a decent bin

The only purpose for DEFAULTB at the moment is to have a safe place to
put packets until all the filters and bins are setup.

]]

print(o,s)
os.exit(-1)
end


-- And away we go
-- FIXME - do something intelligent when faced with a bridge or vlan

itype=qmodel.interface_type(iface)

if itype == 'wireless' or itype == 'ethernet' then
   kernel_prereqs(PREREQS)
   os.execute(sf("tc qdisc del dev %s root",iface))
   tc=io.popen(sf("%s -b",TC),'w')
   if itype == 'wireless' then wireless() end
   if itype == 'ethernet' then ethernet() end
end
