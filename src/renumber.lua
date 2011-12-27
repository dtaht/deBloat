#!/usr/bin/lua

local files="/etc/config/* /etc/babeld.conf /etc/chroot/etc/named/*/*"

-- bin.unpack("CCCC", packet.data, pos)

-- FIXME I want is the std join and/reverse function

function string:split(sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        self:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

-- would prefer to write this as a object function
-- string:join(sep)

local function strjoin(delimiter, list)
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

-- return the number of octets in an address

local function octets(ip)
	return (# ip:split("."))
end

local function rev(items)
	local t = {}
	local c = 1
	for i = #items,1,-1 do
		t[c] = items[i]
		c = c + 1
        end
return t
end

local function revaddr(ip)
	return(strjoin(".",rev(ip:split("."))))
end

local function network_renumber(from, to, files)
	if octets(from) == 3 and octets(to) == 3 then
		io.execute(string.format("sed -i -e s#%s#%s#g -e s#%s#%s#g %s",
			   from,to,revaddr(from),revaddr(to),files))
	end
end

--    revDays = {}
--    for i,v in ipairs(days) do
--      revDays[v] = i
--    end

print(string.format("%d",octets("128.0.0.")))
print(string.format("%d",octets("128.0.0")))
print(string.format("%d",octets("128.0.0.1")))
print(string.format("%s",revaddr("128.0.0.1")))

