module(...,package.seeall)

local sf = string.format
local tc = _G.tc

-- TC tends to be repetitive and hard to read
-- So this shortens things considerably by doing
-- the "{class,qdisc,filter} add dev %s" for us
-- Constructing something that was ** reversible **
-- and cleaner to express would be better that this

local castring=sf("class add dev %s %%s\n",_G.iface)
local fastring=sf("filter add dev %s %%s\n",_G.iface)
local qastring=sf("qdisc add dev %s %%s\n",_G.iface)

local function ca(...) 
      return tc:write(sf(castring,sf(...))) 
end

local function fa(...) 
      return tc:write(sf(fastring,sf(...))) 
end

local function qa(...) 
      return tc:write(sf(qastring,sf(...))) 
end

local function mcast(parent,bin) 
   fa("protocol ip parent %x: prio 5 u32 match u8 0x01 0x01 at -14 flowid %x:%x",parent,parent,bin)
   fa("protocol ipv6 parent %x: prio 6 u32 match u8 0x01 0x01 at -14 flowid %x:%x",parent,parent,bin)
   fa("protocol arp parent %x: prio 7 u32 match u8 0x01 0x01 at -14 flowid %x:%x",parent,parent,bin)
end

