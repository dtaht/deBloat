#!/usr/bin/lua

-- My thought here is to explore how hard it would be
-- to rewrite the fw, classification, and filtering rules
-- in openwrt into pure lua.
-- {CHAIN=string, IFACE=string, COMMENT=string, etc}

-- But for starters, let's just transliterate my old Diffserv code
-- and see what happens.

-- Create a diffserv namespace

WIRELESS_DEVS="wlan0"
WIRED_DEVS="se+ ge+"

DEBUG_LOG="/dev/null"
PRIOIP=""
PRIOIPV6=""

-- IP addresses of the VoIP phones,
-- if none, set VOIPIPS=""

VOIPIPS=""
VOIP6IPS=""
NTPIPS=""

ROBUST_STATS=0


local ds = {
   BE=0,
   AF11=10,
   AF12=12,
   AF13=14,
   AF21=18,
   AF22=20,
   AF23=22,
   AF31=26,
   AF32=28,
   AF33=30,
   AF41=34,
   AF42=36,
   AF43=38,
   EF=46,

   CS1=8,
   CS2=16,
   CS3=24,
   CS4=32,
   CS5=40,
   CS6=48,
   CS7=56,

   BOFH=4,
   ANT=42,
   LB=63,
   P2P=9
}

-- FIXME: Reverse that list

-- DSFREQ table is sorted by frequency of occurrance
DSFREQ = { 'BE', 'CS1', 'CS6', 'BOFH', 'ANT', 'EF', 'AF21', 'AF22', 'AF23',
	  'P2P', 'AF41', 'AF42', 'AF43', 'CS7', 'CS6', 'CS5', 'CS4', 'CS3',
	  'CS2', 'AF11', 'AF12', 'AF13', 'AF31','AF32','AF33','LB' 
       }

-- FIXME - sort into udp, tcp, udptcp catagories

PRIO_PORTS = {
-- Interactive classs: SSH Terminal, DNS and gaming (Quake)
   INTERACTIVE="22,222",
   GAMING="3389,5900,5688",

-- People that use proxies can be shaped better, and 443 is important
-- include spdy, too

   PROXY="8123,3128,8118,1080,443,6127",

-- rdate?
   NTP=123,
   RTP="5004:5005",
   -- ichat? skype?
   -- VoIP telephony
   SIGNAL="5060:5062",
   VOIP="5062:5100,10000:11000,5000:5059,8000:8016,5004,1720,1731,4569",
   VPN="1194,500,4500",
   CHAT="6667,7000,194,5190,5222,5269",
   -- WWW
   BROWSING="80,81,8080",
   --FIXME: icecast, look at some radio stations. Soma uses:
   A_STREAMING="8600,8048,9010,8884,8384,8010,9000",
   --FIXME: netflix, etc
   V_STREAMING="554",
   ZEBRA="2600:2608",
   MONITOR="161:162,199,5777",
   -- Routing
   ROUTING="179,$ZEBRA",
   -- Yes, let's track git and cvs
   SCM="371,2401,3690,9418",
   MAIL="143,220,993,587,465",
   -- Rsync, SMTP
   BULK="25,873,20:21,109:110,119,631,4559",
   -- Traditional filesharing has it's place
   FILE="137:139,369:370,445,2049,7000:7009",
   -- The lowest priority traffic: eDonkey, Bittorrent, etc.
   P2P="110,143,445,4662:4664,6881:6999,540,1214,4031,6346:6347",
   XWIN="177,6000:6010,7100",
   DB="1433:1434,3050,3306,5432:5433,5984",
   BACKUP="9101:9103,10080,13720:13721,13782:13783,2988:2989,10081:10083",
   TEST="5001:5002"
}


ICMP6 = {
   'Ping' = 128,
   'Pong' = 129,
   'Neighbor Solicitation' = 135,
   'Neighbor Advertisement' = 136,
   'Dest Unreachable' = 1,
   'Packet Too Big' = 2,
   'Parameter Problem' = 3,
   'Router Solicitation' = 133,
   'Router Advertisement' = 134,
   'Group Membership query' = 130,
   'Group Membership report' = 131,
   'Group Membership Reduciton' = 132,
   'Redirect' =137,
   'Router Renumbering' =138,
   'Node info query' = 139,
   'Node info response' = 140,
   'Inverse NDS' = 141,
   'Inverse ADV' = 142,
   'MLDv2 Listener Report' = 143,
   'Home agent disc req' = 144,
   'Home agent reply' = 145,
   'Mobile prefix solicit' = 146,
   'Mobile prefix Adv' = 147,
   'Cert path solicit' =148,
   'Cert path Adv' = 149,
   'Experimental mobility' = 150,
   'MRD advertisment' = 151,
   'MRD Solicitation' = 152,
   'MRD Termination' = 153,
   'FMIPv6' = 154 
}

--[
ICMP6 = {
    128, 129,
    135 ='Neighbor Solicitation' = 135,
    136 ='Neighbor Advertisement' = 136,
    1 =  'Dest Unreachable' = 1,
    2 =  'Packet Too Big' = 2,
    3 =  'Parameter Problem' = 3,
    133 ='Router Solicitation' = 133,
    134 ='Router Advertisement' = 134,
    130 ='Group Membership query' = ,
    131 ='Group Membership report' ,
    132 ='Group Membership Reduciton' ,
    137 ='Redirect' ,
    138 ='Router Renumbering' ,
    139 ='Node info query' ,
    140 ='Node info response' ,
    141 ='Inverse NDS' ,
    142 ='Inverse ADV' ,
    143 ='MLDv2 Listener Report' ,
    144 ='Home agent disc req' ,
    145 ='Home agent reply' ,
    146 ='Mobile prefix solicit' ,
    147 ='Mobile prefix Adv' ,
    148 ='Cert path solicit' ,
    149 ='Cert path Adv' ,
    150 ='Experimental mobility' ,
    151 ='MRD advertisment' ,
    152 ='MRD Solicitation' ,
    153 ='MRD Termination' ,
    154 ='FMIPv6' 
}
--]

-- We could use some shortcuts for common ipv6 addrs

i6:laddr = "fe80::/10"
i6:mcast = "ff00::/12" -- fixme

function iptables4(...)
   i4:print(...)
end

function iptables6(...)
   i6:print(...)
end

function iptables(...)
	iptables4(...)
	iptables6(...)
end

function multiport(...)
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

local function dscp_stats()
   local t = "-t filter -A DSCP_STATS -m dscp --dscp-class %d -m comment --comment '%s'   -j RETURN"
   local function f(...)
      iptables(string.format(t,...))
   end
   for i,v in ipairs(DSFREQ) do
      f(ds[v],v)
   end
   iptables("-t filter -A DSCP_STATS -m comment --comment 'Unmatched' -j LOG")
end

local function icmpv6_stats()
   local function f(...)
      iptables6(string.format("-A ICMP6_STATS -p icmpv6 --icmpv6-type %d -m comment --comment '%s' -j RETURN",...))
   end
   for i,v in ipairs(ICMPV6) do f(i,v) end 
end

local function clean()
   for i,v in ipairs({ "filter", "mangle", "raw", "nat" }) do
      iptables(string.format("-t %s -F",v))
      iptables(string.format("-t %s -X",v))
   end
end

local function start()
   clean()
   icmpv6()
   icmpv6_stats()
   dscp_stats()
   classify()
   mac80211e()
   mac8021q()
   finalize()
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
