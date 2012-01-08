#!/usr/bin/lua

-- Use of the QFQ qdisc for ethernet and wireless
-- This script expects to be run in /etc/network/if-pre-up.d
-- To run it manually, do a IFACE=yournetworkcard ./this_script
-- For NATTED interfaces, use a NATTED=y for a better filter
-- To select SFQ use QMODEL=sfq. QMODEL=sfqred
-- (I'll probably make this argv processed soon)
-- It will automatically detect your network interface type
-- and 'do more of the right thing'

-- STA_QFQ currently requires a new version of tc
-- Build a version and stick it somewhere and change
-- this to suit

TC="~d/git/iproute2/tc/tc"
TCARG="-b"

-- TC="/bin/cat"
-- TC="/usr/bin/less"
-- TCARG=" "
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
-- At a hundred megabit, on my hardware I get

-- (with sfq on)
-- BQL = auto ~ 2.16 ms RTT for ping
-- BQL = 4500 ~ 1.2 ms RTT for ping
-- BQL = 3000 ~ .67 ms RTT for ping
-- BQL = 1500 ~ .76 ms RTT for ping
-- With a baseline of .33 ms unloaded
-- And at this level we are no doubt
-- interacting with other optimizations
-- on the stack...

MAX_HWQ_BYTES=3000

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

BIGDISC="pfifo_head_drop limit 24"
MDISC="pfifo limit 32"
NORMDISC="pfifo limit 32"

-- You shouldn't need to touch anything after this line

sf=string.format

NATTED='n'

IFACE=os.getenv("IFACE")
if (IFACE == nil) then 
   print("Error: The IFACE environment variable must be set")
   os.exit(-1) 
end

-- FIXME - use modprobe on linux, insmod on openwrt

QMODEL='qfq'

PREREQS = { 'sch_qfq', 'cls_u32', 'cls_flow' }

if (IFACE == nil) then 
   print("Error: The IFACE environment variable must be set")
   os.exit(-1) 
end

-- Override various defaults with env vars

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

local function is_openwrt() 
   if file_exists("/etc/uci-defaults") then return true else return false end
end

--[ Need to think on this
local function check_prereq(prereqs) 
   if is_openwrt() then 
      for i,v in prereqs do end
   else
      for i,v in prereqs do end
   end
end
--]

if is_openwrt() then
   INSMOD="/sbin/insmod"
   ETHTOOL="/usr/sbin/ethtool"
   TC="/usr/sbin/tc"
else
   INSMOD="/sbin/modprobe"
   ETHTOOL="/sbin/ethtool"
end

FORCE_100MBIT=false

--[ I miss LISP. There's got to be a way to lookup the self name...
local function defaults(param)
   if os.getenv(param) ~= nil then return os.getenv(param) else return valueof(param) end
end
--]

if os.getenv("TC") ~= nil then TC=os.getenv("TC") end
if os.getenv("MDISC") ~= nil then MDISC=os.getenv("MDISC") end
if os.getenv("BIGDISC") ~= nil then BIGDISC=os.getenv("BIGDISC") end
if os.getenv("NORMDISC") ~= nil then NORMDISC=os.getenv("NORMDISC") end
if os.getenv("BINS") ~= nil then BINS=os.getenv("BINS") end
if os.getenv("MAX_HWQ_BYTES") ~= nil then MAX_HWQ_BYTES=os.getenv("MAX_HWQ_BYTES") end
if os.getenv("ETHTOOL") ~= nil then ETHTOOL=os.getenv("ETHTOOL") end
if os.getenv("NATTED") ~= nil then NATTED=os.getenv("NATTED") end
if os.getenv("QMODEL") ~= nil then QMODEL=os.getenv("QMODEL") end
if os.getenv("FORCE_100MBIT") ~= nil then FORCE_100MBIT=os.getenv("FORCE_100MBIT") end

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

local function ethtool(...)
   os.execute(sf("%s %s",ETHTOOL,sf(...)))
end

-- Under most workloads there doesn't seem to be a need
-- to reduce txqueuelen. Reducing the bql tx ring to 64
-- along with a byte limit of 4500 gives a nice symmetry:
-- 60+ ACKS or 3 big packets.

-- FIXME: Handle multi queued interfaces

local function bql_setup(iface)
   local f = io.open(sf("/sys/class/net/%s/queues/tx-0/byte_queue_limits/limit_max",iface),'w')
   if f ~= nil then
      f:write(sf("%d",MAX_HWQ_BYTES))
      f:close()
   else
      print("Your system does not support byte queue limits")
   end
end

-- TSO does terrible things to the scheduler
-- GSO does as well
-- UFO is not a feature of most devices

local function ethernet_setup(iface)
-- for testing, limit ethernet to 100Mbit
   if FORCE_100MBIT then
      ethtool("-s %s advertise 0x008",iface)
      ethtool("-G %s tx 64",iface)
      bql_setup(iface)
   end
   ethtool("-K %s gso off",iface)
   ethtool("-K %s tso off",iface)
   ethtool("-K %s ufo off",iface)
end

-- if type(arg) == 'table' foreach arg self(arg)
-- Some TC helpers

-- TC tends to be repetitive and hard to read
-- So this shortens things considerably by doing
-- the "{class,qdisc,filter} add dev %s" for us
-- Constructing something that was ** reversible **
-- and cleaner to express would be better that this

local castring=sf("class add dev %s %%s\n",IFACE)
local fastring=sf("filter add dev %s %%s\n",IFACE)
local qastring=sf("qdisc add dev %s %%s\n",IFACE)

local function ca(...) 
      return tc:write(sf(castring,sf(...))) 
end

local function fa(...) 
      return tc:write(sf(fastring,sf(...))) 
end

local function qa(...) 
      return tc:write(sf(qastring,sf(...))) 
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

local function wireless_qfq()
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

-- Eric's SFQ enhancements
-- This has htb support which I need to add intelligently
-- $TC qdisc add dev $DEV root handle 1: est 1sec 8sec htb default 1

-- $TC class add dev $DEV parent 1: classid 1:1 est 1sec 8sec htb \
--       rate 200Mbit mtu 40000 quantum 80000

-- $TC qdisc add dev $DEV parent 1:1 handle 10: est 1sec 8sec sfq \
--       limit 2000 depth 10 headdrop flows 1000 divisor 16384

-- This just enables sfq more correctly for wireless.

local function wireless_sfq()
   VO=0x10; VI=0x20; BE=0x30; BK=0x40
   local QUEUES = { BE, VO, VI, BK }
   
   qa("handle 1 root mq")
   qa("parent 1:1 handle %x sfq",VO)
   qa("parent 1:2 handle %x sfq",VI)
   qa("parent 1:3 handle %x sfq",BE)
   qa("parent 1:4 handle %x sfq",BK)
   
   -- FIXME: We must get ALL multicast out of the other queues
   -- and into the VO queue. Always. Somehow.-
end


-- As tested by eric. sfqred. This is designed to be competive with
-- my qfq implementation....
-- I have to think about the calculations for 100Mbit and below...

-- tc qdisc add dev $DEV parent 1:1 handle 10: est 1sec 4sec sfq \
--       limit 3000 headdrop flows 512 divisor 16384 \
--       redflowlimit 100000 min 8000 max 60000 probability 0.20 ecn
-- not done yet

local function wireless_sfq_red()
   VO=0x10; VI=0x20; BE=0x30; BK=0x40
   local QUEUES = { BE, VO, VI, BK }
   
   qa("handle 1 root mq")
   qa("parent 1:1 handle %x sfq",VO)
   qa("parent 1:2 handle %x sfq",VI)
   qa("parent 1:3 handle %x sfq",BE)
   qa("parent 1:4 handle %x sfq",BK)
   
   -- FIXME: We must get ALL multicast out of the other queues
   -- and into the VO queue. Always. Somehow.-

end

local function wireless(model)
	if model == 'sfq' then
		wireless_sfq()
	elseif model == 'qfq' then
		wireless_qfq()
	elseif model == 'sfqred' then
		wireless_sfq_red()
	end
end

local function ethernet(model)
   ethernet_setup(IFACE)
   if model == "qfq" then
	qa("handle %x root qfq",10)
	model_qfq_pfifo_fast(10)
   elseif model == "sfq" then
	qa("handle %x root sfq",10)
   elseif model == "sfqred" then
	qa("handle %x root sfq",10)
   end
end

-- And away we go
-- FIXME - do something intelligent when faced with a bridge or vlan

itype=interface_type(IFACE)

if itype == 'wireless' or itype == 'ethernet' then
   kernel_prereqs(PREREQS)
   os.execute(sf("tc qdisc del dev %s root",IFACE))
   tc=io.popen(sf("%s %s",TC,TCARG),'w')
   if itype == 'wireless' then wireless(QMODEL) end
   if itype == 'ethernet' then ethernet(QMODEL) end
end
