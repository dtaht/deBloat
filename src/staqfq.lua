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

BINS=2048

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

NATTED='n'

-- various shortcuts for commonly used functions

local sf=string.format
local exec=os.execute
local popen=io.popen
local open=io.open
local getenv=os.getenv 

VO=0x10; VI=0x20; BE=0x30; BK=0x40
local WQUEUES = { BE, VO, VI, BK }

IFACE=getenv("IFACE")
if (IFACE == nil) then 
   print("Error: The IFACE environment variable must be set")
   os.exit(-1) 
end

QMODEL="qfq"
PREREQS = { "sch_qfq", "cls_u32", "cls_flow", "sch_sfq", "sch_red" }

-- we can get more complex later

PREREQS2 = { 
   ["qfq"] = { "sch_qfq", "cls_u32", "cls_flow" },
   ["sfq"] = { "sch_sfq", "cls_u32", "cls_flow" },
   ["red"] = { "sch_qfq", "sch_red", "cls_u32", "cls_flow" },
   ["ared"] = { "sch_qfq", "sch_red", "cls_u32", "cls_flow" }
}


-- FIXME: Merge multiple tables into one table on value

function merge(...)
   local t = { }
   for i,v in pairs(...) do
      for i,v in pairs(v) do
	 t[v] = true
      end
   end
   return t
end

-- slurp a file

function slurpf(file)
   local f = open(file,"r")
   if f ~= nil then 
      local s = f:read("*all")
      f:close()
      return s
   end
   return nil
end


-- spew output into a command

function spewc(command,s)
   local f = popen(command,"w")
   if f ~= nil then
      local v = f:write(s) 
      f:close()
      return v
   end
   return nil
end

-- spew output into a file

function spewf(file,s)
   local f = open(file,"w")
   if f ~= nil then
      local v = f:write(s) 
      f:close()
      return v
   end
   return nil
end


-- slurp a file into a table

function tslurpf(file)
   local s = slurpf(file)
   if s ~= nil then return s:split("\n") end
   return nil
end

-- return the output of a command as a big string

function slurpc(command)
   local f = popen(command,"r")
   if f ~= nil then 
      local s = f:read("*all")
      f:close()
      return s
   end
   return nil
end

-- return the output of a command as a table

function tslurpc(command)
   local s = slurpc(command)
   if s ~= nil then return s:split("\n") end
   return nil
end


-- Some utility functions

function file_exists(name)
   local f=open(name,"r")
   if f ~= nil then f:close(); return true else return false end
end


-- can't depend on 'wlan or eth' patterns, so try sysfs
-- FIXME: This needs to be made smarter and detect other forms
-- of tunnel.

function interface_type(iface)
   if iface == 'lo' then return('localhost') end
   if string.sub(iface,1,3) == 'ifb' then return('ifb') end
   if string.find(iface,'%.') ~= nil then return('vlan') end
   if string.sub(iface,1,3) == 'gre' then return('tunnel') end
   if string.sub(iface,1,2) == 'br' then return('bridge') end
   if file_exists(sf("/sys/class/net/%s/phy80211/name",iface)) then return ('wireless') end
return ('ethernet')
end

local function is_openwrt() 
   if file_exists("/etc/uci-defaults") then return true else return false end
end

if is_openwrt() then
   INSMOD="/sbin/insmod"
   LSMOD="/sbin/lsmod"
   ETHTOOL="/usr/sbin/ethtool"
   TC="/usr/sbin/tc"
else
   INSMOD="/sbin/modprobe"
   ETHTOOL="/sbin/ethtool"
   LSMOD="/sbin/lsmod"
end

FORCE_SPEED=0
FORCE_RING=0

--[ I miss LISP. There's got to be a way to lookup the self name...
local function defaults(param)
   if getenv(param) ~= nil then return getenv(param) else return valueof(param) end
end
--]

-- Override various defaults with env vars

if getenv("TC") ~= nil then TC=getenv("TC") end
if getenv("TCARG") ~= nil then TCARG=getenv("TCARG") end
if getenv("MDISC") ~= nil then MDISC=getenv("MDISC") end
if getenv("BIGDISC") ~= nil then BIGDISC=getenv("BIGDISC") end
if getenv("NORMDISC") ~= nil then NORMDISC=getenv("NORMDISC") end
if getenv("BINS") ~= nil then BINS=getenv("BINS") end
if getenv("MAX_HWQ_BYTES") ~= nil then MAX_HWQ_BYTES=getenv("MAX_HWQ_BYTES") end
if getenv("ETHTOOL") ~= nil then ETHTOOL=getenv("ETHTOOL") end
if getenv("NATTED") ~= nil then NATTED=getenv("NATTED") end
if getenv("QMODEL") ~= nil then QMODEL=getenv("QMODEL") end
if getenv("FORCE_SPEED") ~= nil then FORCE_SPEED=getenv("FORCE_SPEED") end
if getenv("FORCE_RING") ~= nil then FORCE_RING=getenv("FORCE_RING") end
if getenv("LSMOD") ~= nil then LSMOD=getenv("LSMOD") end


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

local function ethtool_popen(...)
   return popen(sf("%s %s",ETHTOOL,sf(...)),"r")
end

local function ethtool(...)
   exec(sf("%s %s",ETHTOOL,sf(...)))
end

-- lua doesn't have a split function. Grr.

function string:split(sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

-- return the modules already installed

local function lsmod()
   local t = { }
   local k = { }
   for i,v in pairs(tslurpc(LSMOD)) do
      k = v:split(" ")
      if k[1] ~= "Module" then
	 table.insert(t,k[1])
      end
   end
   return t
end

-- take a table of modules to insert

local function insmod(modules)
     for i,v in pairs(modules) do
	exec(sf("%s %s", INSMOD,v))
     end
     return true
end

-- there must be a more lua-specific way for this

function exists(t,s)
   for i,v in pairs(t) do
      if v == s then return true end
   end
   return false
end

-- Return pre-reqs not installed

function prereq_check(prereqs)
   s = lsmod()
   local t = { }
   for i,v in pairs(prereqs) do
      if exists(s,v) == false then
	 table.insert(t,v)
      end
   end
   return t
end

-- install pre-reqs if not installed

function kernel_prereqs(prereqs)
   return insmod(prereq_check(prereqs))
end

-- FIXME:
-- We want to capture the characteristics of
-- the interface in a table.
-- So we need to parse the output of ethtool better
-- ["tx-ring"] = X
-- ["speed"] = X
-- etc
-- return a hash of the properties of the interface

-- terrific, this is hard to parse.
-- ethtool -g eth0

-- Ring parameters for eth0:
-- Pre-set maximums:
-- RX:		4096
-- RX Mini:	0
-- RX Jumbo:	0
-- TX:		4096
-- Current hardware settings:
-- RX:		256
-- RX Mini:	0
-- RX Jumbo:	0
-- TX:		64

-- ethtool -g wlan0
-- Ring parameters for wlan0:
-- Pre-set maximums:
-- RX:		0
-- RX Mini:	0
-- RX Jumbo:	0
-- TX:		0
-- Current hardware settings:
-- RX:		0
-- RX Mini:	0
-- RX Jumbo:	0
-- TX:		0

-- -k is easier
-- ethtool -k eth0
-- Offload parameters for eth0:
-- rx-checksumming: on
-- tx-checksumming: on
-- scatter-gather: on
-- tcp-segmentation-offload: off
-- udp-fragmentation-offload: off
-- generic-segmentation-offload: off
-- generic-receive-offload: on
-- large-receive-offload: off
-- rx-vlan-offload: on
-- tx-vlan-offload: on
-- ntuple-filters: off
-- receive-hashing: off

-- FIXME

-- FIXME need trim or word command
-- sometimes I really do miss perl

function offloads(iface)
   local t = { }
   for i,v in pairs(tslurpc(sf("%s -k %s",ETHTOOL,iface))) do
      local h = v:split(":")
      t[h[1]] = h[2] -- fixme, whitespace removal needed, on = true, off=false
   end
   return t
end

-- x = offloads("eth0")
-- for i,v in pairs(x) do
--    print("i=",i,"v=",v)
-- end

function ring_params(iface)
   local t = { }
   for i,v in pairs(tslurpc(sf("%s -g %s",ETHTOOL,iface))) do
      local h = v:split(":")
      -- FIXME, now we have to parse the default vs the non-default
      --t[h[1]] = h[2] -- fixme, whitespace removal needed, on = true, off=false
   end
   return t
end


function iface_get(iface)
end


-- Under most workloads there doesn't seem to be a need
-- to reduce txqueuelen. Reducing the bql tx ring to 64
-- along with a byte limit of 4500 gives a nice symmetry:
-- 60+ ACKS or 3 big packets.

-- return number of hardware queues found

local function bql_setup(iface)
   local c = 0
   while spewf(sf("/sys/class/net/%s/queues/tx-%d/byte_queue_limits/limit_max",iface,c),
	       MAX_HWQ_BYTES) ~= nil do
      c = c + 1
   end
   return c
end

-- Maybe better done with ethtool

local function speed_set(iface,speed) 
   return spewf(sf("/sys/class/net/%s/speed",iface),speed)
end

local function speed_get(iface) 
   return slurpf(sf("/sys/class/net/%s/speed",iface)) 
end

-- FIXME: detect speed reliably somehow
-- wireless is hard... wired may vary
-- when going up or down

-- local speedtotxring = 

-- FIXME: Not clear how to reset to advertising all
-- Maybe use ethtool speed option?
-- Think about hashing on this side, too.

-- this had nasty effects on lua's speed
-- local speedtoethtool = { ["100"] = "0x008",
-- 			 ["10"] = "0x002",
-- 		         ["1000"] = "0x020",
-- 			 ["10000"] = "0x1000",
-- 			 ["0"] = "0x1000",
-- 		      }


-- TSO does terrible things to the scheduler
-- GSO does as well
-- UFO is not a feature of most devices

-- In the long run I think we want to disable
-- TSO and GSO entirely below 100Mbit. I'd
-- argue for same for gigE, too, for desktops

local function ethernet_setup(iface)
-- for testing, limit ethernet to SPEED
   if FORCE_SPEED then
      ethtool(sf("-s %s advertise 0x008",iface))
   end
   if FORCE_RING then
      ethtool(sf("-G %s tx %d",iface,FORCE_RING))
   end
   local queues = bql_setup(iface)
   ethtool("-K %s gso off",iface)
   ethtool("-K %s tso off",iface)
   ethtool("-K %s ufo off",iface)
   return queues
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

-- We can do simple per-stream load balancing across multiple hardware queues
-- thusly. This assumes your IPv6 isn't natted.... 

local function mqprio_bins(parent,queues)
if NATTED == 'y' then
   fa("protocol ipv6 parent %x: handle 3 prio 94 flow hash keys proto-dst,rxhash divisor %d",parent,queues)
   fa("protocol all parent %x: handle 3 prio 97 flow hash keys proto-dst,nfct-src divisor %d",parent,queues)
else
   fa("protocol all parent %x: handle 3 prio 97 flow hash keys proto-dst,rxhash divisor %d",parent,queues)
end
-- At one point I was trying to handle ipv6 separately
-- fa("protocol ipv6 parent %x: handle 4 prio 98 flow hash keys proto-dst,rxhash divisor %d",parent,BINS)
end

-- Eric's Enhanced SFQ 

-- FIXME: hard coded for 200Mbit
-- I'm going to argue that depth, flows, speed all need to be
-- done via something kleinrock-like. The problem is that 
-- we don't know the delay without hitting the next hop
-- And we can't get the next hop until after the interface is
-- up. And even then we can only measure RTT, which is off
-- by a factor of three on the two different systems I've looked at

-- FIXME: I don't think I should be measuring speed in megabits
-- Eric's original code had a mtu of 40000, which I assume is needed for TSO/GSO to work.
-- These quantums are way too large for lower speeds

local function htb_sfq(speed,flows)
   qa("root handle 1: est 1sec 8sec htb default 1")
   ca("parent 1: classid 1:1 est 1sec 8sec htb rate 200Mbit mtu 1500 quantum 80000")
   qa("parent 1:1 handle 10: est 1sec 8sec sfq limit 2000 depth 10 headdrop flows 1000 divisor 16384")
end

local function htb_sfq_red(speed,flows)
   qa("root handle 1: est 1sec 8sec htb default 1")
   ca("parent 1: classid 1:1 est 1sec 8sec htb rate 200Mbit mtu 1500 quantum 80000")
   qa("parent 1:1 handle 10: est 1sec 4sec sfq limit 3000 headdrop flows 512 divisor 16384 redflowlimit 100000 min 8000 max 60000 probability 0.20 ecn")
end

local function efq(parent, handle, speed, flows)
   qa(sf("parent %s handle %x: est 1sec 8sec sfq limit 2000 depth 24 headdrop flows %d divisor 16384",
	 parent,handle,flows))
end

local function efqr(parent, handle, speed, flows)
   qa(sf("parent %s handle %x: est 1sec 4sec sfq limit 3000 headdrop flows %d divisor 16384 redflowlimit 100000 min 8000 max 60000 probability 0.20 ecn",parent,handle,speed,flows))
end

-- Iptables wrappers that we need due to lack of filters
-- Maybe use a DEBLOAT chain. It would be good to have a universal number
-- to reduce the number of match rules
-- iptables -t mangle -o iface -I POSTROUTING -m multicast ! unicast --classify 1:1

local function iptables_probe(iface,rule)
end

local function iptables_remove(iface,rule)
end

local function iptables_insert(iface,rule)
end

-- Basic SFQ on wireless
-- FIXME: We must get ALL multicast out of the other queues
-- and into the VO queue. Always. Somehow. 
-- It also makes sense to do EF into the VO queue
-- and match the default behavior inside of the 
-- MAC80211 code for scheduling purposes

local function wireless_filters()
-- FIXME: We need filters to use the various queues
-- The only way to get them is to use iptables presently
end

local function wireless_setup(queuetype)
   qa("handle 1 root mq")
   qa("parent 1:1 handle %x %s",VO, queuetype)
   qa("parent 1:2 handle %x %s",VI, queuetype)
   qa("parent 1:3 handle %x %s",BE, queuetype)
   qa("parent 1:4 handle %x %s",BK, queuetype)
   wireless_filters()
end


-- Various models


local function wireless_sfq()
   wireless_setup("sfq")
end

-- erics sfq and erics sfqred with 
-- some arbitrary speeds and bandwidths (unused)
-- TiQ would be better

local function wireless_efq()
   qa("handle 1 root mq")
   efq("1:1",VO,20,30)
   efq("1:2",VI,150,20)
   efq("1:3",BE,150,1000)
   efq("1:4",BK,50,10)
   wireless_filters()
end

local function wireless_efqr()
   qa("handle 1 root mq")
   efqr("1:1",VO,20,30)
   efqr("1:2",VI,100,20)
   efqr("1:3",BE,150,1000)
   efqr("1:4",BK,50,10)
   wireless_filters()
end

-- FIXME: add HTB rate limiter support for a hm gateway
-- What we want are various models expressed object orientedly
-- so we can tie them together eventually
-- This is not that. We ARE trying to get to where the numbering
-- schemes are consistent enough to tie everything together
-- sanely...

local function model_qfq_subdisc(base)
   cb(base,MULTICAST,MDISC)
   cb(base,DEFAULTB,NORMDISC)
   fa_defb(base)
   fa_mcast(base); 
   q_bins(base);
   fa_bins(base); 
end

-- FIXME: Finish this up

local function model_qfq_ared(base)
   cb(base,MULTICAST,MDISC)
   cb(base,DEFAULTB,NORMDISC)
   fa_defb(base)
   fa_mcast(base); 
   q_bins(base);
   fa_bins(base); 
end

local function model_qfq_red(base)
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

-- Wireless devices are multi-queued - BUT the hardware
-- enforces differences in behavior vs the queues
-- (actually hostapd does that)
-- FIXME: get a grip on lua iterators

local function wireless_qfq()
   wireless_setup("qfq")
   for i,v in ipairs(WQUEUES) do
      model_qfq_subdisc(v)
   end
end

local function wireless_qfqr()
   wireless_setup("qfq")
   for i,v in ipairs(WQUEUES) do
      model_qfq_ared(v)
   end
end

-- FIXME: just stubs for now

local function wireless_ared()
   qa("handle 1 root mq")   
   for i,v in ipairs(WQUEUES) do
      model_qfq_ared(v)
   end
   wireless_filters()
end

-- FIXME: just stubs for now

local function wireless_red()
   qa("handle 1 root mq")
   for i,v in ipairs(WQUEUES) do
      model_qfq_red(v)
   end
   wireless_filters()
end

-- FIXME - mqprio might not be available
-- FIXME - rethink multi-queue idea

local function ethernet_qfq(queues)
   c = queues
--   for i=0,c do
   if queues > 1 then
      qa("handle %x root qfq",10)
   else
      qa("handle %x root qfq",10)
   end
   model_qfq_subdisc(10)
end

local function ethernet_sfq(queues)
	 qa("handle %x root sfq",10)
end

local function ethernet_efq(queues)
	 qa("handle %x root sfq",10)
end

local function ethernet_efqr(queues)
	 qa("handle %x root sfq",10)
end

-- FIXME: just stubs for now

local function ethernet_ared(queues)
	 qa("handle %x root sfq",10)
end

local function ethernet_red(queues)
	 qa("handle %x root sfq",10)
end


-- I have to think about the calculations for 100Mbit and below...

-- FIXME: Think on the architecture and models harder
-- first. Need to also be able to stick HSFC or HTB
-- on top of this

WCALLBACKS = { ["qfq"] = wireless_qfq, 
	       ["qfqred"] = wireless_qfqr,
	       ["red"] = wireless_red,
	       ["ared"] = wireless_ared,
	       ["sfq"] = wireless_sfq,
	       ["efq"] = wireless_efq,
	       ["efqred"] = wireless_efqr }

ECALLBACKS = { ["qfq"] = ethernet_qfq, 
	       ["qfqred"] = ethernet_qfqr,
	       ["red"] = ethernet_red,
	       ["ared"] = ethernet_ared,
	       ["sfq"] = ethernet_sfq,
	       ["efq"] = ethernet_efq,
	       ["efqred"] = ethernet_efqr }

-- couple other models - dsl, wshaper, etc, needed
-- pingopt and argv processing too

local function wireless(model)
   if WCALLBACKS[model] ~= nil then 
      return WCALLBACKS[model]() 
   end
   return nil
end

local function ethernet(model)
   if ECALLBACKS[model] ~= nil then 
      return ECALLBACKS[model](ethernet_setup(IFACE)) 
   end
   return nil
end

-- FIXME - do something intelligent when faced with a bridge or vlan

itype=interface_type(IFACE)

if itype == 'wireless' or itype == 'ethernet' then
   kernel_prereqs(PREREQS)
   exec(sf("tc qdisc del dev %s root",IFACE))
   tc=popen(sf("%s %s",TC,TCARG),'w')
   if itype == 'wireless' then wireless(QMODEL) end
   if itype == 'ethernet' then ethernet(QMODEL) end
end
