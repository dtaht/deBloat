#!/usr/bin/lua

require "cero"
require "fping"

g = {}
c = 1

PCOUNT=600
ips = { }
vals = { }

f = fping.fping(PCOUNT,"172.30.50.1 172.30.48.1 172.30.49.1")
s = f:read("*all")
t = s:split("\n")

function process(t)
   local ips = {}
   local vals = {}
   for i,v in pairs(t) do
      local k = {}
      k = v:split(":")
      ips[c] = k[1]
      vals[ips[c]] = k[2]:split(" ")
      c = c + 1 
   end
   return  ips,vals
end

ips, vals = process(t)

function org_header(title,t)
   io.write("|",title)
   for i,v in ipairs(t) do
      io.write("|",v)
   end
   io.write("|\n")
   io.write("|-+")
   for i,v in ipairs(t) do
      io.write("-+")
   end
   io.write("|\n")
end

org_header("T",ips)

-- FIXME - handle '-' as a empty datapoint

C= # t
for j=1,PCOUNT do
   io.write("|",j,"|")
   for i=1,C do
      local t = vals[ips[i]]
      io.write(t[j],"|")
   end
   io.write("\n")
end
