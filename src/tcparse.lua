#!/usr/bin/lua
TC="~d/git/iproute2/tc/tc"
IFACE=os.getenv("IFACE")
tc=io.popen(string.format("%s -s class show dev %s",TC,IFACE),"r")

local l=""
while true do
   local o = tc:read("*line")
   if o == nil then 
      io.write(string.format("%s %s\n",l,o))
      break
   end

   if string.sub(o,1,1) == ' ' then
      l = string.format("%s\t%s",l,o)
   else
      io.write(string.format("%s\n",l))
      l = o
   end

end