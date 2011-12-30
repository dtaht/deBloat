module(..., package.seeall);

-- Isolate system dependent vars in ceroenv

-- ceroenv = {}
-- setmetatable(ceroenv)
-- local barplotmt = {__index = luaplot.barplot}

ceroenv = { TC, MDISC, BIGDISC, NORMDISC, BINS, MAX_HWQ_BYTES, 
	      ETHTOOL, NATTED, QMODEL, FORCE_100MBIT, INSMOD, LSMOD,
	      IPTABLES4, IPTABLES6, HOME, SHELL }

local ge = os.getenv
local exec = os.execute
local popen = io.popen
local sf = string.format

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

local function is_openwrt() 
   if file_exists("/etc/uci-defaults") then 
      return true 
   else 
      return false 
   end
end

function getenvs(t)
   n = { }
   for i,v in pairs(t) do
      print(i)
      s = ge(i)
      if s ~= nil then print(s); n[i] = s else n[i] = v end
   end
   return n
end

-- Some reasonable defaults
-- not clear how to inherit these across multiple instances

function new()
   ceroenv.QMODEL="sfq"
   ceroenv.MAX_HWQ_BYTES=4500
   ceroenv.BIGDISC="pfifo limit 24"
   ceroenv.MDISC="pfifo limit 16"
   ceroenv.NORMDISC="pfifo limit 32"
   ceroenv.LSMOD="/sbin/lsmod"
   -- Maybe just rely on nil value
   ceroenv.FORCE_100MBIT=false
   ceroenv.NATTED="n"
   if is_openwrt() then
      ceroenv.INSMOD="/sbin/insmod"
      ceroenv.ETHTOOL="/usr/sbin/ethtool"
      ceroenv.TC="/usr/sbin/tc"
   else
      ceroenv.INSMOD="/sbin/modprobe"
      ceroenv.ETHTOOL="/sbin/ethtool"
      ceroenv.TC="/usr/sbin/tc"
   end
   ceroenv = getenvs(ceroenv)
   return(ceroenv)
 end

-- FIXME: convert boolean to string

function show()
   for i,v in pairs(ceroenv) do
      print(sf("%s=%q",i,v))
   end
end

-- wonder how to do a factory pattern?

function insmod(...)
   return popen(sf("%s %s",ceroenv.INSMOD,sf(...)),"r")
end

function lsmod()
   return popen(ceroenv.LSMOD,"r")
end

function ethtool(...)
   return popen(sf("%s %s",ceroenv.ETHTOOL,sf(...)),"r")
end

function tc(...)
   return popen(sf("%s %s",ceroenv.TC,sf(...)),"w")
end

-- FIXME: Can't find table

prereq = function (prereqs) 
   local o = lsmod()
   local s = o:read("*all")
   o:close()
   for i,v in pairs(prereqs) do 
      print(sf("finding %s",v))
      if string.find(s,v) == nil then
	 print("inserting module")
	 local err = insmod(v)
	 if err ~= 0 then return(nil) end
      end
   end
   return(true)
end

