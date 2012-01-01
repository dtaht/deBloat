-- Various wrappers for fping
-- fping -c count ip ip ip ip

module(...,package.seeall)
require ("cero")

-- local popen = io.popen                     
-- local exec = cero.exec
local sf = string.format
-- local string:split = cero.string:split

function string:split(sep)
   local sep, fields = sep or ":", {}
   local pattern = sf("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

function lines(str)
  local t = {}
  local function helper(line) table.insert(t, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

ip="172.30.48.1"

-- FPING sends the easy to parse summary data to STDERR!!!
-- so I just rewrote it around this wrapper

FPING="/usr/bin/qfping"

-- local FPING = cero:findexe("fping")
-- FIXME: What we really want is an fping object

local function fp(s)
   return io.popen(sf("%s %s",FPING,s),"r")
end

-- Output format is EASY
-- fping -q -C 10  172.30.48.1 172.30.50.1
-- 172.30.48.1 : 0.56 0.46 0.26 0.49 0.33 0.52 0.30 0.52 0.29 0.29
-- 172.30.50.1 : 0.33 0.40 0.34 0.38 0.25 0.25 0.31 0.21 0.28 0.32

function fping(c,ip) 
   return fp(sf("%d %s",c,ip))
end

-- We want to get sanely formatted results out of  various fping tests
-- as well as additional information about the test

-- table to json 
-- csv to table

function to_json(t)
end

-- FIXME: Want to sort it vertically by ip address

function to_org(t)
   for i,v in pairs(t) do
      for i2,v2 in ipairs(v.ip) do
      print(sf("|%s|%s|",v.ip,v2))
      end
   end
end

function process(s)
   t = {}
   t = lines(s)
   return(t)
end

--    for i,v in ipairs(t) do 
--       g = v:split(":")
--       g["IP"] = g[1]
--       if g[2] ~= nil then
-- 	 local f = g[2]
-- 	 r = f:split(" ")
-- 	 for z,b in pairs(r) do
-- 	    print(z,b)
-- 	 end
-- 	 g[g["IP"]] = r
--       end
--       -- for j,k in pairs(g) do
--       -- 	  r = k:split(" ")
--       -- 	  print("j=",j,"k=",k)
--       -- 	  for o,n in pairs(r) do
--       -- 	     print("o=",o,"n=",n)
--       -- 	  end
--    end
--    return(g)
-- end
-- --       end
      
       -- FIXME - represent loss as infinity or something other than -
--       r[g[1]] = g[2]:split(" ")
--       print("G1 =",g[1],"G2=",g[2])
--    end
--end

function runtest(tmon)
   t = { }
   while # tmon > 0 do
      local s = ""
      for i,v in ipairs(tmon) do
	 s = v:read("*all")
	 if s == nil then 
	    table.remove(tmon,i) 
	 else 
	    t = process(s)
	 end
      end
   end
   return t
end

