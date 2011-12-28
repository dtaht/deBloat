#!/usr/bin/lua
-- Presently the interfaces are hanging once in a while
-- This kicks them periodically

require "socket"

local debloat="/etc/debloat"

local function sleep(sec) 
   socket.select(nil,nil,sec)
end

local function reset(iface)
   print(string.format("AGGH! Resetting %s",iface))
   os.setenv(string.format("IFACE=%s",iface))
   os.execute(debloat)
end

local function monitor(interfaces, timeout)
 
   local a = { }
   local o= { }
   local n = { }
   local s = { } 
   for i,v in ipairs(interfaces) do
      s[i] = string.format("/sys/class/net/%s/statistics/tx_packets",v)
      a[i] = io.open(s,"r")
      n[i] = 0
      o[i] = 0
   end
   
   while true do
      for i,v in ipairs(interfaces) do
	 n[i] = a[i]:read("*n")
	 a[i]:close()
	 if o[i] == n[i] then
	    reset(v)
	 else
	    print (string.format("%s: %d %d", v, o[i], n[i]))
	    o[i] = n[i]
	 end
	 a[i] = io.open(s[i],"r")
      end
      sleep(timeout)
   end
end

monitor({ "ge00", "se00" })
-- monitor({ "eth0" }, 5)