#!/usr/bin/lua

require "diffserv"

ds = diffserv

function iptables4(...)
   print(string.format("iptables %s",...))
end

function iptables6(...)
--   print(string.format("ip6tables %s",...))
end

function iptables(...)
   iptables4(...)
   iptables6(...)
end

function multiport(...)
end

--recreate_filter
--{
--   tab="mangle",
--   chain="none"
--}

function recreate_filter(t)
   assert(t.chain, "ERROR: chain parameter is missing!")
   assert(t.table, "ERROR: table parameter is missing!")
   iptables(string.format("-t %s -X %s", t.table, t.chain))
   iptables(string.format("-t %s -Z %s", t.table,t.chain))
   iptables(string.format("-t %s -X %s", t.table,t.chain))
   iptables(string.format("-t %s -N %s", t.table,t.chain))
end

-- What we want to eventually get to is where we can use tools
-- like a=std, f=map(a.filter({SWEB, TESTS,WEB}))
-- f.WEB:do_something()

-- There is no easy way to mark codepoints that you aren't using back 
-- into something sane. A syntax like ! --dscp-map-class CP,CP,CP,CP,CP
-- would be helpful, as with a single 64 bit mask we could reclassify
-- something in 2 rules rather than 64
-- (also useful would be to use unassigned codepoints above, too)
-- It is very amusing most web traffic is CS1
-- So we drop everything else into a BE catagory 
-- processing, for now...

function site_ingress(iface) 
   local p = string.format("-i %s -A INGRESS -m dscp --dscp %%d -j DSCP --set-dscp %%d",iface)
   local function f(m,s)
      iptables(string.format(p,m,s))
   end
   f(ds.CS7,ds.BE)
   f(ds.LB,ds.BE)
   for i=1,63 do if ds[i] == nil then f(i,ds.BE) end end
end

function p80_rathole()
   recreate_filter{table=mangle,chain=P80RATHOLE}
   local p = "-t mangle -A P80RATHOLE -m dscp --dscp %d -m recent --name p80_%d --set"
   local function f(m,s)
      iptables(string.format(p,m,s))
   end
   for i=0,63 do f(i,i) end
end

function dscp_WEB()
   local p = "-t mangle -A WEB -m dscp %s --dscp %d -j DSCP --set-dscp %d -m comment --comment '%s'"
   local function f(n,m,m2,c)
      iptables(string.format(p,n,m,m2,c))
   end

   recreate_filter{table="mangle",chain="SWEB"}
   recreate_filter{table="mangle",chain="TESTS"}
   recreate_filter{table="mangle",chain="WEB"}

   if p80_stats ~= nil then 
      p80_rathole()
      iptables("-t mangle -A WEB -j P80RATHOLE")
   end

   f("!",ds.CS1,ds.AF23,"BE BROWSING")
   f("",ds.CS1,ds.AF23,"BK BROWSING")
--   f("", $iptables -t mangle -A SWEB -j DSCP --set-dscp-class AF21 \
--	-m comment --comment 'Proxies/433'
--    $iptables -t mangle -A TESTS -j DSCP --set-dscp-class CS1 -m comment \
--	    --comment 'Bandwidth Tests'
end

-- create a bunch of rules for dscp classification
-- maybe this is an ip level match now

local function dscp_target(proto,dscp)
   return(string.format("DSCP_%s_%s",proto,dscp))
end

local function dscp_classify_create()
   for i=0,63 do
      for n,proto in ipairs(ds.PROTOS) do
	 iptables(string.format("-t mangle -X %s",dscp_target(proto,i)))
	 iptables(string.format("-t mangle -N %s",dscp_target(proto,i)))
	 iptables(string.format("-t mangle -A %s -p %s -m %s -j DSCP --set-dscp %d",dscp_target(proto,i),proto,proto,i))
	 iptables(string.format("-t mangle -A %s -j RETURN",dscp_target(proto,i)))
      end
   end
end

-- I am not sure why I used tcp and udp distinctions. 
-- FIXME - do udp right
-- would probably have been saner in many cases
-- FIXME: Do other protocols (41,50,51,58) Be thorough.


function classify() 
      t = { ["table"] = "mangle" }
      chains = { STATS_ECN, BIMODAL, SYN_EXEPEDITE, ANTS, Ants_END, D_CLASSIFIER, D_CLASSIFIER_END, BROWSING }
      for i,v in ipairs(chains) do
	 t["chain"] = v
	 recreate_filter(t)
      end

      local function se(a,c) 
	 iptables(string.format("-t mangle -A SYN_EXPEDITE -p tcp -m tcp %s -j DSCP --set-dscp-class AF11 -m comment --comment '%s'",a,c))
      end

-- I'm not certain this is a good idea, but the initial syn and syn/ack is a mouse.
-- as are fins and fin/acks, sorta. And we usually do interesting stuff on syns

      se("--syn", "Expedite Syn attempts")
      se("--tcp-flags ALL SYN,ACK","Expedite new connection ack") 

-- FIXME: Maybe make ECN enabled streams mildly higher priority. 
-- This just counts the number of ECN and non-ECN streams
-- FIXME: Also mark against IP not TCP

      local function ecn_stats(...) 
	 iptables(string.format("-t mangle -A STATS_ECN -p tcp -m tcp --tcp-flags ALL SYN,ACK -m ecn %s -m recent --name %s --set -m comment --comment '%s'",...))
      end
      ecn_stats("--ecn-tcp-ece","ecn_enabled","ECN Enabled")
      ecn_stats("! --ecn-tcp-ece","ecn_disabled","ECN disabled")

-- FIXME, we want to see the whole state table
--      ecn_stats("--ecn-tcp-ece","ecn_asserted","ECN Asserted") -- ??

      local function bimodal(...) 
	 iptables(string.format(" -t mangle -A BIMODAL -p tcp -m tcp -m multiport --ports %s -m dscp %s --dscp %s -m comment --comment '%s'",...))
      end

-- FIXME: Multiple other flows are also bimodal

      bimodal(ds.ports.INTERACTIVE,"",ds.BOFH,"", "SSH Interactive")
      bimodal(ds.ports.INTERACTIVE,"! ",ds.BOFH .. " -j DSCP --set-dscp-class CS1 ","SSH Bulk")

      local function ants(...) 
	 iptables(string.format(" -A Ants -p udp -m multiport --ports %s -j DSCP --set-dscp %d -m comment --comment '%s'",...))
      end

      ants("53,67,68",ds.ANT,'DNS, DHCP, are very important')
      ants(ds.ports.SIGNAL,ds.CS5,'VOIP Signalling')
      ants(ds.ports.VOIP .. "," .. ds.ports.NTP,ds.EF,'VOIP')
      ants(ds.ports.GAMES, ds.CS4, 'Gaming')
      ants(ds.ports.MONITOR, ds.CS2, 'SNMP')

      local function mcast6(...) 
	 iptables6(string.format("-t mangle -A Ants %s -j DSCP --set-dscp %d -m comment --comment '%s'",...))
      end

      mcast6("-s fe80::/10 -d fe80::/10",ds.ANT,'Link Local sorely needed')
      mcast6("-d ff00::/12",ds.AF43,'Multicast far less needed') 
      mcast6("-s fe80::/10 -d ff00::/12", ds.ANT, 'But link local multicast is good')
      mcast6("-d ff00::/12 -m multiport --port 123", ds.CS6, "Multicast NTP")

-- As is neighbor discovery, etc, but I haven't parsed 
-- http://tools.ietf.org/html/rfc4861 well yet
-- $iptables -t mangle -A Ants -s fe80::/10 -d ff00::/12 \
-- -j DSCP --set-dscp-class AF12 -m comment 
-- --comment 'ND working is good too' \
-- As for other forms of icmp, don't know
--didn't work
--$iptables -t mangle -A Ants -m addrtype --dst-type MULTICAST 
---j DSCP --set-dscp-class AF22 -m comment --comment 'Multicast'
      --Some forms of multicast are good, others bad, but for now...
--      mcast("-m pkttype --pkt-type MULTICAST",ds.AF43,'Multicast')

-- Arp replies? DHCP replies?
-- Main stuff

      iptables("-t mangle -A D_CLASSIFIER ! -p tcp -g Ants")

-- 98% of traffic these days is on the web
-- FIXME: Actually reclassifying web traffic needs a new idea

      dscp_WEB()

-- This set of rules cuts performance down to less that 50Mbit/sec
-- for the bottommost rules. Since we're trying to get to where we
-- have CPU left over AND can see bufferbloat, do the test match first
-- gotos are good

      local function sf(...)
	 iptables(string.format("-t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport --ports %s -g %s -m comment --comment '%s'",...))
      end
      sf(ds.ports.TEST,'TESTS','Tests')
      sf(ds.ports.BROWSING,'BROWSING','Browsing')
      sf(ds.ports.PROXY,'SWEB','Proxies/433')
      sf(ds.ports.INTERACTIVE,'BIMODAL','SSH')
      local function lf(ports,dscp,comment)
	 iptables(string.format("-t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport --ports %s -g %s -m comment --comment '%s'",ports,dscp_target("tcp",dscp),comment))
      end
      lf(ds.ports.XWIN,ds.CS4,'Xwindows')
      lf(ds.ports.GAMES,ds.CS4,'Gaming')
      lf(ds.ports.ROUTING,ds.CS6,'Routing') -- FIXME: Routing takes place over many protocols
      lf(ds.ports.SCM,ds.AF13,'SCM') -- Arguably want a better class for git. Bulk?
      lf(ds.ports.DB,ds.AF12,'DB') 
      lf(ds.ports.V_STREAM,ds.AF43,'Video')
      lf(ds.ports.A_STREAM,ds.AF41,'Internet Radio')
      lf(ds.ports.FILE,ds.AF22,'Normal File sharing')
      lf(ds.ports.MAIL,ds.AF32,'MAIL clients')
      lf(ds.ports.BACKUP,ds.CS3,'Backups')
      lf(ds.ports.BULK,ds.CS1, 'BULK')
      lf(ds.ports.P2P,ds.P2P, 'PTP') -- There is no codepoint for torrent.
end

-- Fixme, memoize
-- { "dscp", "newclass", "comment" }

local function mac80211e() 
   local t = "-t mangle -A W80211e -m dscp --dscp %d -j CLASSIFY --set-class 1:%d -m comment --comment '%s'"
   local function f(...)
      iptables(string.format(t,...))
   end
   
   recreate_filter({table="mangle",chain="W80211e"})
   
   iptables("-t mangle -A W80211e -j CLASSIFY --set-class 0:103 -m comment --comment 'Reclassify BE'")
   f(ds.EF,  107,'Voice (EF)')
   f(ds.CS6, 106,'Critical (VO)')
   f(ds.ANT, 105,'Ants(VI)')
   f(ds.BOFH,105,'Typing (VI)')
   f(ds.AF41,104,'Net Radio(VI)')
   f(ds.CS3, 104,'Video (VI)')
   f(ds.CS1, 102,'Background (BK)')
   f(ds.CS5, 101,'General Stuff (BK)')
   f(ds.P2P, 101,'P2P (BK)')
   f(ds.CS2, 102,'Background (BK)')
   f(ds.AF33,102,'Background (AF33)')
-- FIXME re-mark multicast for VO
end

local function sch_md() 
   local t = "-t mangle -A SCH_MD -m dscp --dscp %d -j CLASSIFY --set-class 1:%d -m comment --comment '%s'"
   local function f(...)
      iptables(string.format(t,...))
   end
   
   recreate_filter({table="mangle",chain="SCH_MD"})
   
   iptables("-t mangle -A SCH_MD -j CLASSIFY --set-class 1:3 -m comment --comment 'Reclassify BE'")
   f(ds.EF,  1,'Voice (EF)')
   f(ds.CS6, 2,'Critical (VO)')
   f(ds.ANT, 2,'Ants(VI)')
   f(ds.BOFH,2,'Typing (VI)')
   f(ds.AF41,2,'Net Radio(VI)')
   f(ds.CS3, 2,'Video (VI)')
   f(ds.CS1, 4,'Background (BK)')
   f(ds.CS5, 4,'General Stuff (BK)')
   f(ds.P2P, 4,'P2P (BK)')
   f(ds.CS2, 4,'Background (BK)')
   f(ds.AF33,4,'Background (AF33)')
-- FIXME re-mark multicast for VO
end

local function mac8021q() 
   local t = "-t mangle -A W8021q -m dscp --dscp %d -j CLASSIFY --set-class 1:%d -m comment --comment '%s'"
   local function f(...)
      iptables(string.format(t,...))
   end
   
   recreate_filter({table="mangle",chain="W8021q"})
   
   iptables("-t mangle -A W8021q -j CLASSIFY --set-class 0:103 -m comment --comment 'Reclassify BE'")
   f(ds.EF,  107,'Voice (EF)')
   f(ds.CS6, 106,'Critical (VO)')
   f(ds.ANT, 105,'Ants(VI)')
   f(ds.BOFH,105,'Typing (VI)')
   f(ds.AF41,104,'Net Radio(VI)')
   f(ds.CS3, 104,'Video (VI)')
   f(ds.CS1, 102,'Background (BK)')
   f(ds.CS5, 101,'General Stuff (BK)')
   f(ds.P2P, 101,'P2P (BK)')
   f(ds.CS2, 102,'Background (BK)')
   f(ds.AF33,102,'Background (AF33)')
end

local function dscp_stats()
   local t = "-t filter -A DSCP_STATS -m dscp --dscp %d -m comment --comment '%s' -j RETURN"
   local function f(...)
      iptables(string.format(t,...))
   end
   recreate_filter{table="filter",chain="DSCP_STATS"}
   for i,v in ipairs(ds.DSFREQ) do
      f(ds[v],v)
   end
   iptables("-t filter -A DSCP_STATS -m comment --comment 'Unmatched' -j LOG")
end

local function icmpv6_stats()
   local function f(...)
      iptables6(string.format("-A ICMP6_STATS -p icmpv6 --icmpv6-type %s -m comment --comment '%s' -j RETURN",...))
   end
   recreate_filter{table="filter",chain="ICMP6_STATS"}
   for i,v in pairs(ds.ICMPV6) do f(v,i) end 
end

local function clean()
   for i,v in ipairs({ "filter", "mangle", "raw", "nat" }) do
      iptables(string.format("-t %s -F",v))
      iptables(string.format("-t %s -X",v))
   end
end

local function start()
   clean()
   recreate_filter{table="mangle",chain="Ants"}
   recreate_filter{table="mangle",chain="D_CLASSIFIER"}
   recreate_filter{table="mangle",chain="STATS_ECN"}
   recreate_filter{table="mangle",chain="BIMODAL"}
   recreate_filter{table="mangle",chain="BROWSING"}
--   recreate_filter{table="mangle",chain="Ants"}
--   icmpv6()
   dscp_classify_create()
   icmpv6_stats()
   dscp_stats()
   classify()
   mac80211e()
   mac8021q()
   sch_md()
--   finalize()
end

local function stop() 
   clean()
end

local function restart() 
   stop()
   start()
end

local function status4() 
   iptables4("-x -v -n -L DSCP_STATS")
end

local function status6() 
   iptables6("-x -v -n -L DSCP_STATS")
   iptables6("-x -v -n -L ICMP6_STATS")
end

local function status() 
   print("IPV6 Stats")
   status6()
   print("IPV4 Stats")
   status4()
end

local function help() 
end

start()