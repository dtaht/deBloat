-- Wrapper for layer 4 traceroute
-- Returns a clean table, one table per hop
-- t["HOP"],t["IP"],t["MIN"],t["MAX"]

module(...,package.seeall)

require ("cero")  
local sf = string.format

-- What we really want of course is to run all this stuff
-- at the same time with non-blocking reads. Which is hard.

comment = [[

-m 60 -T

traceroute to www.lwn.net (72.51.34.34), 30 hops max, 60 byte packets
 1  172.17.2.1  10.136 ms  2.012 ms
 2  82.247.114.254  41.957 ms  118.416 ms
 3  78.254.0.94  114.997 ms  112.701 ms
 4  78.254.255.9  109.240 ms  107.551 ms
 5  78.254.255.5  109.173 ms  108.183 ms
 6  78.254.254.33  106.599 ms  106.232 ms
 7  * *
 8  212.27.50.173  103.273 ms  85.662 ms
 9  212.27.57.190  82.379 ms  81.310 ms
10  212.27.58.26  159.367 ms  156.046 ms
11  206.223.115.30  160.729 ms  155.825 ms
12  216.187.115.38  177.110 ms  159.685 ms
13  216.187.120.225  232.390 ms  219.677 ms
14  216.187.124.117  202.634 ms  185.867 ms
15  216.187.124.133  179.538 ms  177.747 ms
16  216.187.124.121  198.494 ms  218.607 ms
17  216.187.88.46  199.762 ms  203.570 ms
18  * *
19  72.51.34.34  194.746 ms  192.352 ms

Usage: /usr/bin/lft [-ACEFINRSTUVbehinpruvz] [-d dport] [-s sport]
[-m retry min] [-M retry max] [-a ahead] [-c scatter ms] [-t timeout ms]
[-l min ttl] [-H max ttl] [-L length] [-q ISN] [-D device] [--help]
   [gateway ...]  target:dport
   
]]

env = { dport, sport, retry_min, retry_max, ahead, scatter, timeout, ttl_min, ttl_max, len, iface }

LFT="/usr/bin/lft"

-- We need to check if we are root to run certain kinds of traceroute

function lft(ip)
   return io.popen(string.format("%s -n %s",LFT,ip),"r")
end

-- return nicely cleaned up table
-- hop = [i], table ip=x, min=x, max=x
-- 0.0.0.0, math.huge for unknown values

function parser(s)
   w = { }
   t = { HOP, IP, MIN, MAX }
   NEXTFIELD="MIN"
   w = s:split(" ")
   -- FIXME I hate string matching - multiple fields separated by spaces, * as a special ugh
   for i,v in pairs(w) do
      if i == 1 then t["HOP"] = v end
      if i == 2 then
	 if v == '*' then 
	    t["IP"] = "0.0.0.0"
	 else
	    t["IP"] = v
	 end
      end
      if v ~= "ms" and i > 2 then
	 if v == "*" then t[NEXTFIELD] = math.huge
	 else
	    t[NEXTFIELD] = v
	 end
	 NEXTFIELD="MAX"
      end
   end
   
   if t["MIN"] == nil then t["MIN"] = math.huge end
   if t["MAX"] == nil then t["MAX"] = math.huge end
   print(t["HOP"],t["IP"], t["MIN"], t["MAX"])
   return(t)
end

function tracert(ip)
   t1 = { }
   t  = { }
   o = lft(ip)
   s = o:read("*all")
   o:close()
   if (s) then 
      t1 = s:split("\n")
      local c = 1
      for i,v in ipairs(t1) do
	 if i ~= 1 then	t[c] = parser(v); c = c + 1 end
      end
   end
   return t
end

-- function tcptraceroute
-- function udptraceroute
-- function icmptraceroute

function traceroute(ip)
   return tracert(ip)
end
