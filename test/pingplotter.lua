-- Massage the data first
-- indicate packet loss on a separate graph
-- and offset for each ip enough to show on a graph
-- eliminate outliers above some percentile on main graph
-- also show outliers - VERY IMPORTANT - on a log scale
-- so like we could mark the outliers with their actual time
-- clean up data on input - c = x, where rtt = null
-- 95% confidence interval
-- reserve one pixel below the graph for the dropped pings 
-- for each 

require "cero"
require "cerodb"

local sf = string.format
local to_value = cerodb.to_sqlvaluestr
local strjoin = cero.strjoin

temptables = { [[
create temp table graph_desc (
   id varchar(30),
   x_axis float,
   y_axis float,
)
]] }

con = { }

function hw_by_confidence_intervals(interval)
--   interval = .95
   max_y = 0
   for i,v in ids do
      local y = gen_max("fping_raw","rtt",v,interval)
      if y ~= nil and max_y > y then max_y = y end
   end
   max_x = sqlmono(sf("select max(c) from fping_raw where id in (%s)",sqlquote(ids)))
   return max_x, max_y
end

function createtemps()
for i,v in pairs(temptables) do
   if sqlmono(v) ~= nil then return nil end
   end
end

function gnuplot() 
   return popen("gnuplot","w")
end

function creategnuplot() 
output = [[
set terminal png nocrop enhanced font arial 8 size 1000,1000
set output 'pingplot.1.png'
set dummy t,y
set format x "%3.2f"
set format y "%3.2f"
set format z "%3.2f"
unset key 
set parametric
set samples 100, 100
set style function dots
set title "Ping RTT under load"
set xlabel "RTT"
set xrange [ 0.00000 : 30.00000 ] noreverse nowriteback
set ylabel "Time"
set yrange [ 0.00000 : 100.00000 ] noreverse nowriteback
set datafile separator ','
plot "ab.csv" using 2:1 title 'localhost', "ab2.csv" using 2:1 title 'next hop'
]]
o = gnuplot()
o:write(output)
o:close()
end

doit() 
con = db.init()
assert (createtemps())
max_y, max_y = hw_by_confidence_intervals(.95)

end

-- show dropped pings on a fixed graph

-- show outliers on a log scale

-- generate gnuplot