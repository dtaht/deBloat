#!/usr/bin/lua

-- timestamp,sourceip,srcport,dstip,dstport,unknown,timerange,something,something
-- 20111228174427,172.30.50.2,36249,172.30.49.27,5001,3,0.0-10.1,23461888,18612244
-- sqlval = strjoin(",",table:join(t)

-- module(...,

-- load driver
require "luasql.postgres"
require "cero"

local sf = string.format
local to_value = cero.to_sqlvaluestr
local fromCSV = cero.fromCSV
local strjoin = cero.strjoin

sf("wtfs %d",1)

ip="172.30.48.1"
tests="iperf -yc -t %d -w256k -c %s"

numtests=10
tmon = { }

totalbytes=0
bytespersec=0

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
   cur = assert (con:execute("SELECT ts, sum(bytes) as bytes, sum(bytes_sec) as bytes_sec from iperf_raw group by ts"))
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
   cur = con:execute("SELECT * from iperf_raw")
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
   res = assert (con:execute(string.format("INSERT INTO iperf_raw %s",to_value(s))))
   con:commit()
   return(res)
end

local function iperfprint(s)
   local t = fromCSV(s)
   dbinsert(t)
   for i,v in ipairs(t) do print(i,v) end
   totalbytes= totalbytes + t[8]
   bytespersec= bytespersec + t[9]
end

local function runtest(args)
   return io.popen(args,"r")
end

--function dbsummary()
--   row = cur:fetch ({}, "a")
-- end

dbinit()
dbsummary()

t = string.format(tests,5,ip)

for i=1,numtests do
   tmon[i] = runtest(t)
end

while # tmon > 0 do
   local s = ""
   for i,v in ipairs(tmon) do
      s = v:read("*l")
   if s == nil then 
      table.remove(tmon,i) 
   else 
      iperfprint(s)
   end
   end
end

con:commit()
print(string.format("Total KBytes: %d\nMBit/sec: %d",totalbytes/1024, bytespersec/1024))
dbprint()
print("Summary of tests")
dbsummary()
dbsummary_org()
