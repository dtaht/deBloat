#!/usr/bin/lua

require("lft")

a = lft.traceroute("www.lwn.net")
if a ~= nil then
	for i,v in pairs(a) do
	print(v["IP"],v["MAX"])
	end
end

