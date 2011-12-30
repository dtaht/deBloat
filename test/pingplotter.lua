-- Massage the data
-- indicate packet loss with a small negative number
-- and offset for each ip enough to show on a graph
-- eliminate outliers above some percentile
-- also show outliers - VERY IMPORTANT
-- so like we could mark the outliers with their actual time
-- clean up data on input - c = x, where rtt = null
-- 95% confidence interval
-- reserve one pixel below the graph for the dropped pings 
-- for each 

graphs

create temp table graph_desc (
   x_axis float,
   y_axis float,
);

create temp table results inherit from some other table;

function gen_max(table,field,id,interval)
   c = sql.mono(sf("select count(*) as c from %s where id = '%s' and %s not null",table,id,field));
   c = math:abs(c * interval)
   return(sql.mono(sf("select max(b) from (select %s as b from %s where id = '%s' and %s is not null order by %s limit %d) as b",
		      field, table, id, id, field, c)))
end

interval = .95
max_y = 0
for i,v in ids do
   local y = gen_max("fping_raw","rtt",v,interval)
   if y ~= nil and max_y > y then max_y = y end
end
max_x = sql.mono(sf("select max(c) from fping_raw where id in (%s)",sqlquote(ids)))

-- show dropped pings on a fixed graph

-- show outliers on a log scale
