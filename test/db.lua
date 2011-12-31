module (..., package.seeall)

require "luasql.postgres"
require "cero"

local sf = string.format
local to_value = cero.to_sqlvaluestr
local fromCSV = cero.fromCSV
local strjoin = cero.strjoin

ip="172.30.48.1"
tests="iperf -yc -t %d -w256k -c %s"

numtests=10
tmon = { }

env = { }
con = { }

function init()
   env = assert (luasql.postgres())
   con = assert (env:connect("d"))
   return con
end

-- return a single result from a query

function sqlmono(s)
   cur = con:execute(s)
   row = cur:fetch ({}, "a")
   return(row[1])
end

-- Return 
-- FIXME - specify a negative argument to get the reverse

function gen_max(table,field,id,interval)
   c = sqlmono(sf("select count(*) as c from %s where id = '%s' and %s not null",table,id,field));
   c = math:abs(c * interval)
   return(sqlmono(sf("select max(b) from (select %s as b from %s where id = '%s' and %s is not null order by %s limit %d) as b",
		      field, table, id, id, field, c)))
end

function fieldnames(t)
   s = { }; c = 1
   for i,v in pairs(t) do s[c] = i; c = c + 1; end
   return s
end

-- org-mode output!

function summary_org()
   cur = assert (con:execute("SELECT ts, sum(bytes) as bytes, sum(bytes_sec) as bytes_sec from iperf_raw group by ts"))
   row = cur:fetch ({}, "a")
   print(sf("|%s|",strjoin("|",fieldnames(row))))
   while row do
      print(sf("|%s|%s|%s|", row.ts, row.bytes, row.bytes_sec))
      row = cur:fetch (row, "a")
   end
end

function summary()
   cur = assert (con:execute("SELECT ts, sum(bytes) as bytes, sum(bytes_sec) as bytes_sec from iperf_raw group by ts"))
   row = cur:fetch ({}, "a")
   print(strjoin("\t",fieldnames(row)))
   while row do
      print(sf("%s\t%s\t%s", row.ts, row.bytes, row.bytes_sec))
      row = cur:fetch (row, "a")
   end
end

function print()
   cur = con:execute("SELECT * from iperf_raw")
   row = cur:fetch ({}, "a")
--   print(cero:strjoin("\t",fieldnames(row)))
   while row do
      print(sf("%s\t%s\t%s\t%s\t%s\t", row.ts, row.srcip, row.dstip, row.duration, row.bytes, row.bytes_sec))
      row = cur:fetch (row, "a")
   end
end

function close()
   con:close()
   env:close()
end

function insert(s)
   print(to_value(s))
   res = assert (con:execute(string.format("INSERT INTO iperf_raw %s",to_value(s))))
   con:commit()
   return(res)
end

-- 

function iperfprint(s)
   local t = fromCSV(s)
   dbinsert(t)
   for i,v in ipairs(t) do print(i,v) end
   totalbytes= totalbytes + t[8]
   bytespersec= bytespersec + t[9]
end

function runtest(args)
   return io.popen(args,"r")
end

function runtest(numtests,func)

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
      func(s)
   end
   end
end
