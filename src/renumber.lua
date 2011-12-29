#!/usr/bin/lua

require "cero"

local files="/etc/config/* /etc/babeld.conf /etc/chroot/etc/named/*/*"

local function network_renumber(from, to, files)
	if noctets(from) == 3 and noctets(to) == 3 then
		cero.exec(string.format("sed -i -e s#%s#%s#g -e s#%s#%s#g %s",
			   from,to,revaddr(from),revaddr(to),files))
	end
end

--    revDays = {}
--    for i,v in ipairs(days) do
--      revDays[v] = i
--    end


