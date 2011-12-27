#!/usr/bin/lua

-- Use of the QFQ qdisc for ethernet and wireless
-- This script expects to be run in /etc/network/if-pre-up.d
-- To run it manually, do a IFACE=yournetworkcard ./this_script
-- For NATTED interfaces, use a NATTED=y for a better filter

-- STA_QFQ currently requires a new version of tc
-- Build a version and stick it somewhere and change
-- this to suit

TC="~d/git/iproute2/tc/tc -b"

-- TC="/usr/bin/less"

-- QFQ can handle up to 32k bins
-- whether you are willing to wait for them
-- to be generated is a better question
-- how this interacts with bittorrent etc
-- is also a good question. 512 is 4x
-- as many bins as SFQ, sooo....

BINS=512

-- (I have tested as many as 2048 bins)
-- Ran out of kernel memory at 32000

-- Byte Queue Limits is supposed to have a 
-- rate limiter that works. It doesn't, quite.
-- This seems to be the best compromise 
-- for 100Mbit

MAX_HWQ_BYTES=4500

-- I have tried pfifo_drop_head and RED here.
-- both had bugs until recently. And linux RED,
-- being byte oriented, is just not good.
-- pfifo_drop_head was 'interesting' and I
-- may return to it.

-- Obviously calculating a sane per-queue
-- packet limit is an issue, too. 
-- iw10 requires a minimum of 10, and 
-- more likely 12 (fin, close)... so...
-- arbitrarily double that, wave hands.
-- I almost never see packet drop with
-- 24, which is far, far better than 1000.
-- might need to be larger on gigE+

BIGDISC="pfifo limit 24"
MDISC="pfifo limit 16"
NORMDISC="pfifo limit 32"

-- You shouldn't need to touch anything after this line

NATTED='n'

IFACE=os.getenv("IFACE")
if (IFACE == nil) then 
   print("Error: The IFACE environment variable must be set")
   os.exit(-1) 
end

ETHTOOL='/sbin/ethtool'

-- FIXME - use modprobe on linux, insmod on openwrt

INSMOD='/sbin/modprobe'
QMODEL='qfq'

PREREQS = { 'sch_qfq', 'cls_u32', 'cls_flow' }

if (IFACE == nil) then 
   print("Error: The IFACE environment variable must be set")
   os.exit(-1) 
end

-- Override various defaults with env vars

if os.getenv("TC") ~= nil then TC=os.getenv("TC") end
if os.getenv("MDISC") ~= nil then MDISC=os.getenv("MDISC") end
if os.getenv("BIGDISC") ~= nil then BIGDISC=os.getenv("BIGDISC") end
if os.getenv("NORMDISC") ~= nil then NORMDISC=os.getenv("NORMDISC") end
if os.getenv("BINS") ~= nil then BINS=os.getenv("BINS") end
if os.getenv("MAX_HWQ_BYTES") ~= nil then MAX_HWQ_BYTES=os.getenv("MAX_HWQ_BYTES") end
if os.getenv("ETHTOOL") ~= nil then ETHTOOL=os.getenv("ETHTOOL") end
if os.getenv("NATTED") ~= nil then NATTED=os.getenv("NATTED") end
if os.getenv("QMODEL") ~= nil then QMODEL=os.getenv("QMODEL") end

-- Maltreat multicast especially. When handed to a load balancing 
-- filter based on IPs, multicast addresses are all over the map.
-- It would be trivial to do a DOS with this multi-bin setup
-- So we toss all multicast into a single bin all it's own.

MULTICAST=BINS+1

-- You can do tricks with the DEFAULTB concept, creating a filter
-- to optimize for ping, for example, which makes tests reproducable
-- Another example would be to set aside bins for voip
-- or dns, etc. Still, it's saner to just let the filter
-- do all the work of finding a decent bin

-- The only purpose at the moment is to have a safe place
-- to put packets until all the filters and bins are setup.

DEFAULTB=BINS+2

-- Some utility functions

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

-- FIXME: quiet the warnings

function kernel_prereqs(prereqs)
   for i,v in ipairs(prereqs) do
      os.execute(string.format("%s %s",INSMOD,v))
   end
end

-- can't depend on 'wlan or eth' patterns, so try sysfs
-- FIXME: This needs to be made smarter and detect other forms
-- of tunnel.

function interface_type(iface)
   if iface == 'lo' then return('localhost') end
   if string.sub(iface,1,3) == 'ifb' then return('ifb') end
   --   if string.find(iface,'.') ~= nil then return('vlan') end syntax issue fixme
   if string.sub(iface,1,3) == 'gre' then return('tunnel') end
   if string.sub(iface,1,2) == 'br' then return('bridge') end
   if file_exists(string.format("/sys/class/net/%s/phy80211/name",iface)) then return ('wireless') end
return ('ethernet')
end

-- Under most workloads there doesn't seem to be a need
-- to reduce txqueuelen. Reducing the bql tx ring to 64
-- along with a byte limit of 4500 gives a nice symmetry:
-- 60+ ACKS or 3 big packets.

-- TSO does terrible things to the scheduler
-- GSO does as well
-- UFO is not a feature of most devices

local function ethernet_setup(iface) 
   os.execute(string.format("%s -G %s tx 64",ETHTOOL,iface))
   os.execute(string.format("%s -K %s gso off",ETHTOOL,iface))
   os.execute(string.format("%s -K %s tso off",ETHTOOL,iface))
   os.execute(string.format("%s -K %s ufo off",ETHTOOL,iface))
-- for testing, limit ethernet to 100Mbit
   os.execute(string.format("%s -s %s advertise 0x008",ETHTOOL,iface))
end

-- FIXME: Handle multi queued interfaces

local function bql_setup(iface)
   local f = io.open(string.format("/sys/class/net/%s/queues/tx-0/byte_queue_limits/limit_max",iface),'w')
   if f ~= nil then
      f:write(string.format("%d",MAX_HWQ_BYTES))
      f:close()
   else
      print("Your system does not support byte queue limits")
   end
end

-- if type(arg) == 'table' foreach arg self(arg)
-- Some TC helpers

-- TC tends to be repetitive and hard to read
-- So this shortens things considerably by doing
-- the "{class,qdisc,filter} add dev %s" for us
-- Constructing something that was ** reversible **
-- and cleaner to express would be better that this

local castring=string.format("class add dev %s %%s\n",IFACE)
local fastring=string.format("filter add dev %s %%s\n",IFACE)
local qastring=string.format("qdisc add dev %s %%s\n",IFACE)

local function ca(...) 
      return tc:write(string.format(castring,string.format(...))) 
end

local function fa(...) 
      return tc:write(string.format(fastring,string.format(...))) 
end

local function qa(...) 
      return tc:write(string.format(qastring,string.format(...))) 
end

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
if NATTED == 'y' then
   fa("protocol ipv6 parent %x: handle 3 prio 94 flow hash keys proto-dst,rxhash divisor %d",parent,BINS)
   fa("protocol all parent %x: handle 3 prio 97 flow hash keys proto-dst,nfct-src divisor %d",parent,BINS)
else
   fa("protocol all parent %x: handle 3 prio 97 flow hash keys proto-dst,rxhash divisor %d",parent,BINS)
end
-- At one point I was trying to handle ipv6 separately
-- fa("protocol ipv6 parent %x: handle 4 prio 98 flow hash keys proto-dst,rxhash divisor %d",parent,BINS)
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
end

local function ethernet()
   ethernet_setup(IFACE)
   bql_setup(IFACE)
   qa("handle %x root qfq",10)
   model_qfq_pfifo_fast(10)
end

-- And away we go
-- FIXME - do something intelligent when faced with a bridge or vlan

itype=interface_type(IFACE)

if itype == 'wireless' or itype == 'ethernet' then
   kernel_prereqs(PREREQS)
   os.execute(string.format("tc qdisc del dev %s root",IFACE))
   tc=io.popen(TC,'w')
   if itype == 'wireless' then wireless() end
   if itype == 'ethernet' then ethernet() end
end
