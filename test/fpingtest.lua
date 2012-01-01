#!/usr/bin/lua

-- load driver
require "luasql.postgres"
require "cero"

local sf = string.format
local to_value = cero.to_sqlvaluestr
local fromCSV = cero.fromCSV
local strjoin = cero.strjoin

ip="172.30.48.1"
-- -q option or -s option are also useful
tests="fping -c %d %s"
tmon = { }
env = { }
con = { }

function dbinit()
   env = assert (luasql.postgres())
   con = assert (env:connect("d"))
end

local function fieldnames(t)
   s = { }; c = 1
   for i,v in pairs(t) do s[c] = i; c = c + 1; end
   return s
end

-- org-mode output!

function dbsummary_org()
   cur = assert (con:execute("SELECT ts, sum(bytes) as bytes, sum(bytes_sec) as bytes_sec from fping_raw group by ts"))
   row = cur:fetch ({}, "a")
   print(sf("|%s|",strjoin("|",fieldnames(row))))
   while row do
      print(sf("|%s|%s|%s|", row.ts, row.bytes, row.bytes_sec))
      row = cur:fetch (row, "a")
   end
end

function dbsummary()
   cur = assert (con:execute("SELECT ts, sum(bytes) as bytes, sum(bytes_sec) as bytes_sec from iperf_raw group by ts"))
   row = cur:fetch ({}, "a")
   print(strjoin("\t",fieldnames(row)))
   while row do
      print(sf("%s\t%s\t%s", row.ts, row.bytes, row.bytes_sec))
      row = cur:fetch (row, "a")
   end
end

function dbprint()
   cur = con:execute("SELECT * from fping_raw")
   row = cur:fetch ({}, "a")
--   print(cero:strjoin("\t",fieldnames(row)))
   while row do
      print(sf("%s\t%s\t%s\t%s\t%s\t", row.ts, row.srcip, row.dstip, row.duration, row.bytes, row.bytes_sec))
      row = cur:fetch (row, "a")
   end
end

local function dbclose()
   con:close()
   env:close()
end

local function dbinsert(s)
   print(to_value(s))
   res = assert (con:execute(string.format("INSERT INTO fping %s",to_value(s))))
   con:commit()
   return(res)
end

-- We have three kinds of output from fping
-- 172.30.48.1 : [0], 96 bytes, 0.23 ms (0.23 avg, 0% loss)
-- 172.30.48.1 : xmt/rcv/%loss = 5/5/100% min/avg/max = 0.23/0.26/0.30
-- 172.30.49.1 : xmt/rcv/%loss = 5/0/100%

ip, mesg = split (" : ",s)
t = split("=",mesg)
if # t = 0 then 
-- strip out ) % and [] somehow, replace ( with ,
-- 0, 96 bytes x ms y avg 0% loss

elseif # t = 1 then -- summary with total loss
elseif # t = 2 then -- full summary 
end

e.ip = ip
e.c = c
e.min =
e.avg = 
e.max =
e.rtt =
e.loss =
e.xmit =
e.bytes =

   ip["ip"].[c] = e
 
-- indicate packet loss with a small negative number
-- and offset for each ip enough to show on a graph
-- eliminate outliers above some percentile
-- also show outliers - VERY IMPORTANT
-- so like we could mark the outliers with their actual time

local function fpingprint(s)
   
   local t = fromCSV(s)
--   dbinsert(t)
   for i,v in ipairs(t) do print(i,v) end
end

local function runtest(args)
   return io.popen(args,"r")
end

--function dbsummary()
--   row = cur:fetch ({}, "a")
-- end

-- dbinit()
-- dbsummary()

t = string.format(tests,5,ip)

tmon[1] = runtest(t)

while # tmon > 0 do
   local s = ""
   for i,v in ipairs(tmon) do
      s = v:read("*l")
   if s == nil then 
      table.remove(tmon,i) 
   else 
      fpingprint(s)
   end
   end
end
