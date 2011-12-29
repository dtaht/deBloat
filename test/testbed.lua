-- Testbed utility functions
-- A long term goal here is to be able to reflash a ton of routers
-- FROM a router. 
-- And do it automatically (e.g - from a pull from the build server)
-- Which is why this is in lua.

module(...,package.seeall)



-- host = { ["host"], ["user"], ["port"] }

function scp(t)
end

function new_cero_box()
-- remove old keys
-- copy ssh key over
-- renumber
   -- setup ipv4
   -- setup ipv6
-- rename box
   -- change ssid
   -- change system name
-- setup time
-- disable firewalling if needed
   -- enable babel on external dev
-- setup dns
-- setup rsync
-- mount filesystem if available
-- install test tools
-- add to pdsh
-- do a backup
-- reboot
end

function reflash_cero()
-- grab old data 
   -- store by mac address
-- send new data for reflashing
-- reflash
-- wait
-- do new cero box
end

-- lua sql seems well documented
-- that said sql seems a bit overmuch for a simple app
-- I was originally thinking git + json
-- Still need a conf file for various params
-- I mostly do org mode now
-- the idea of NOT going through an intermediate layer
-- however has potential. I need to look into how big
-- postgres client libs are on an openwrt box
-- But lets develop something to store a lab log in
-- regardless, and have to write a sql version anyway

require "luasql.postgres"

--[
create table iperf_log (
   user varchar(10),
   ts   timestamp,
   duration double,
   transferred double,
   transferred_sec double
)  
--]

-- FIXME: use a read cursor and a write cursor
-- for replication purposes sqlr, sqlw

require "luasql.postgres"

function iperf_to_db(t) 
   t2 = { }
   env = luasql.postgres()
   sql = env:connect("dbname=d") -- or sourcename, username, password, hostname, port 
   ins =  "INSERT INTO iperf_log VALUES (%s,%s,%s,%s,%s)" 
   sel =  "SELECT * from iperf_log"
   res = sql:execute(sf(ins,args(t)))
   if res ~= nil then res:commit(); res:close() end
   res = sql:execute(sel)
   while res:fetch(t2,"a") ~= nil do 
      print(strjoin(",",t2))
   end
   res:close()
   env:close()
end

