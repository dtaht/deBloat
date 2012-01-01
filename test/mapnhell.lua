#!/usr/bin/lua

require "cero"
require "fping"
require "lisplike"

mapn = lisplike.mapn

-- There has got to be a better way to express this than this
-- but my brain crashed (or lua did) when I tried it.

function of(s,...) 
   return(sf(s,...))
end

function o2(t1,t2,t3)
   return mapn(function(a,b,c) return ("|" .. a .. "|" .. b .. "|" ) end, t1,t2 )
end

function o3(t1,t2,t3)
   return mapn(function(a,b,c) return ("|" .. a .. "|" .. b .. "|" .. c .. "|" ) end, 
	       t1,t2,t3 )
end

-- function o4(t1,t2,t3,t4)
--      return mapn(function(a,b,c,d) return of(s4,a,b,c,d) end, t1,t2,t3,t4 )
-- end

-- Can't I just write this?


function wtf(...)
   local c = # ...
   s = string.format("|%s",string.rep("%s|",c))
   return mapn(function(...) return (string.format(s,...)) end, ...)
end

-- this almost works

function wtf2(c,...)
   s = string.format("|%s",string.rep("%s|",c))
   return mapn(function(...) return (string.format(s,...)) end, ...)
end

-- this almost works

function gimmie(c,...)
   local s = string.format("|%s",string.rep("%s|",c))
   return(string.format(s,...))
end


--   s = string.rep("%s|",#...)

--function pn(...)
--   return mapn(function(...) return (table.concat(...,"|")) end, ... )
--end

-- j = mapn(function(a,b,c) return (a .. "|" .. b .. "|" .. c) end, {1,2,3},{5,6,7},{8,9,10} )


-- aa = o3({1,2,3},{5,6,7},{8,9,10})

-- for i,v in pairs(aa) do
--   print(v)
-- end

-- WTF? Only joins 3 of the 5 tables

-- aa = wtf({1,2,3},{5,6,7},{8,9,10},{11,12,13},{14,15,16})

-- print(table.concat(aa,"\n"))

-- but wtf2 figures it out right

-- aa = wtf2(5,{1,2,3},{5,6,7},{8,9,10},{11,12,13},{14,15,16})

-- print(table.concat(aa,"\n"))

f = fping.fping(5,"172.30.50.1 172.30.48.1")
s = f:read("*all")
print(s)
-- t = fping.process(s)
g = {}
t = s:split("\n")
c = 1
ips = { }
vals = { }

for i,v in pairs(t) do
   local k = {}
   k = v:split(":")
   ips[c] = k[1]
   vals[ips[c]] = k[2]:split(" ")
--   g[c] = k[2]
   c = c + 1 
--   for l,b in pairs(k) do
--      g[l] 
--      print(i,"WTF",b)
end

-- for i,v in pairs(ips) do
--   print(v)
-- end

-- print(gimmie(2,ips))

-- for i,v in ipairs(ips) do
--   io.write("|",v)
-- end
-- io.write("|\n")

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

org_header("t",ips)

for j=1,5 do
   io.write("|",j,"|")
   for i=1,2 do
      local t = vals[ips[i]]
      io.write(t[j],"|")
   end
   io.write("\n")
end

-- for i,v in ipairs(ips) do
--      io:write("|",i,"|",v,"|")
--    for j,k in pairs(v) do
--       print(k)
--   end
-- end

tablesize = # ips
print("WTF!!")
wtf(vals)
print("WTF2!!")

-- for i,v in pairs(vals) do
   
-- end

-- for i,v in pai

-- ab = wtf2(2,g)
-- print("WTF")
-- print(table.concat(ab,"\n"))
--   for j,k in pairs(r["MS"]) 
-- print(r["ip"])
-- t = fping.runtest(test)

-- fping.to_org(r )

presidents = {
	{lname = "Obama", fname = "Barack", from = 2009, to = nil},
	{lname = "Bush", fname = "George W", from = 2001, to = 2008},
	{lname = "Bush", fname = "George HW", from = 1989, to = 1992},
	{lname = "Clinton", fname = "Bill", from = 1993, to = 2000}
}
