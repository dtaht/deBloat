module(...,package.seeall)
require "ceroenv"

-- can't depend on 'wlan or eth' patterns, so try sysfs
-- FIXME - deal with tunnels and vlans

function interface_type(iface)
   if iface == 'lo' then return('localhost') end
   if string.sub(iface,1,3) == 'ifb' then return('ifb') end
   if string.find(iface,'%.') ~= nil then return('vlan') end
   if string.sub(iface,1,3) == 'gre' then return('tunnel') end
   if string.sub(iface,1,2) == 'br' then return('bridge') end
   if file_exists(string.format("/sys/class/net/%s/phy80211/name",iface)) then 
      return ('wireless') 
   end
   return ('ethernet')
end

-- Under most workloads there doesn't seem to be a need
-- to reduce txqueuelen. Reducing the bql tx ring to 64
-- along with a byte limit of 4500 gives a nice symmetry:
-- 60+ ACKS or 3 big packets.

-- FIXME: Handle multi queued interfaces

local function bql_setup(iface,bytes)
   local f = io.open(string.format("/sys/class/net/%s/queues/tx-0/byte_queue_limits/limit_max",iface),'w')
   if f ~= nil then
      f:write(string.format("%d",MAX_HWQ_BYTES))
      f:close()
      return true
   else
      print("Your system does not support byte queue limits")
      return false
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

end

end

local function ethernet()
   ethernet_setup(IFACE)
   if QMODEL == "qfq" then
      qa("handle %x root qfq",10)
      model_qfq_pfifo_fast(10)
   end
end

-- And away we go
-- FIXME - do something intelligent when faced with a bridge or vlan

itype=interface_type(IFACE)

if itype == 'wireless' or itype == 'ethernet' then
   kernel_prereqs(PREREQS)
   os.execute(string.format("tc qdisc del dev %s root",IFACE))
   tc=io.popen(string.format("%s -b",TC),'w')
   if itype == 'wireless' then wireless() end
   if itype == 'ethernet' then ethernet() end
end
