#!/usr/bin/lua

-- module(...,
require "cero"
require "csv"

ip="172.30.49.27"
tests="iperf -yc -t %d -w256k -c %s"

numtests=10
tmon = { }

totalbytes=0
bytespersec=0

local function iperfprint(s) 
   local t = csv:fromCSV(s)
   for i,v in ipairs(t) do print(i,v) end
   totalbytes= totalbytes + t[8]
   bytespersec= bytespersec + t[9]
end


local function runtest(args)
   return io.popen(args,"r")
end

t = string.format(tests,10,ip)

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

print(string.format("Total KBytes: %d\nMBit/sec: %d",totalbytes/1024, bytespersec/1024))