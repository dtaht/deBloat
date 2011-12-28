#!/usr/bin/lua

ip="172.30.49.27"
tests="iperf -yc -t %d -w256k -c %s"

numtests=10
tmon = { }

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

totalbytes=0
bytespersec=0

local function iperfprint(s) 
   local t = fromCSV(s)
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