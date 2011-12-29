-- Grabbag of Cerowrt related utilities and functions

module(...,package.seeall)

local sf = string.format

-- FIXME I want is the std join and/reverse function

function string:split(sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

-- would prefer to write this as a object function
-- table:join(sep)

function strjoin(delimiter, list)
  local len  = # list
  if len == 0 then 
    return "" 
  end
  local string = list[1]
  for i = 2, len do 
    string = string .. delimiter .. list[i] 
  end
  return string
end

-- reverse a table

function rev(items)
   local t = {}
   local c = 1
   for i = #items,1,-1 do
      t[c] = items[i]
      c = c + 1
   end
   return t
end

function octets(ip)
   return (ip:split("."))
end

-- return the number of octets in an address
-- FIXME - make more robust. Maybe make work with ipv6

function noctets(ip)
   return (# octets(ip))
end

function revaddr(ip)
   return(strjoin(".",rev(octets(ip))))
end

function test_net()
   print(string.format("%d",octets("128.0.0.")))
   print(string.format("%d",octets("128.0.0")))
   print(string.format("%d",octets("128.0.0.1")))
   print(string.format("%s",revaddr("128.0.0.1")))
end

-- FIXME: We want to wrap io.execute (posix?)
-- to send stuff to the log not stdout

function exec(...) 
   io.execute(...)
end

-- misc sql stuff

-- This needs to be WAY more robust

function sqlquote(t)
   n = { }
   for i,v in pairs(t) do
      n[i] = sf("'%s'",v)
   end
   return n
end

function sqlfield(t)
   for i,v in pairs(t) do
      n[i] = i
   end
   return n
end

function to_sqlvaluestr(t)
   return(sf("VALUES (%s)",strjoin(",",sqlquote(t))))
end

function fromCSV (s)
   s = s .. ','        -- ending comma
   local t = {}        -- table to collect fields
   local fieldstart = 1
   repeat
      -- next field is quoted? (start with `"'?)
      if string.find(s, '^"', fieldstart) then
	 local a, c
	 local i  = fieldstart
	 repeat
            -- find closing quote
            a, i, c = string.find(s, '"("?)', i+1)
	 until c ~= '"'    -- quote not followed by quote?
	 if not i then error('unmatched "') end
	 local f = string.sub(s, fieldstart+1, i-1)
	 table.insert(t, (string.gsub(f, '""', '"')))
	 fieldstart = string.find(s, ',', i) + 1
      else                -- unquoted; find next comma
	 local nexti = string.find(s, ',', fieldstart)
	 table.insert(t, string.sub(s, fieldstart, nexti-1))
	 fieldstart = nexti + 1
      end
   until fieldstart > string.len(s)
   return t
end
