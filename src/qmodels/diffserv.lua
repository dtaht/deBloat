-- Diffserv module

module(...,package.seeall)

require "cero"

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

--

-- Lets pretend we can object orient an iptables interface

protocol = { udp, tcp, all, icmp, icmpv6, sctp, hipl }
iptable  = { iface, chain, ichain, multiport, protocol, comment }
matches  = { multiport, multicast, iprange, ecn, recent }
actions  = { ports, jump, goto }
policies = { allow, deny, log, ulog, nfacct, permit }


BE=0
AF11=10
AF12=12
AF13=14
AF21=18
AF22=20
AF23=22
AF31=26
AF32=28
AF33=30
AF41=34
AF42=36
AF43=38
EF=46

CS1=8
CS2=16
CS3=24
CS4=32
CS5=40
CS6=48
CS7=56
BOFH=4
ANT=42
LB=63
P2P=9

-- FIXME: Reverse that list

-- DSFREQ table is sorted by frequency of occurrance
DSFREQ = { 'BE', 'CS1', 'CS6', 'BOFH', 'ANT', 'EF', 'AF21', 'AF22', 'AF23',
	  'P2P', 'AF41', 'AF42', 'AF43', 'CS7', 'CS6', 'CS5', 'CS4', 'CS3',
	  'CS2', 'AF11', 'AF12', 'AF13', 'AF31','AF32','AF33','LB' 
       }

-- FIXME: Really, really want hipl

PROTOS = { 'ip', 'tcp', 'udp', 'sctp', 'tcpudp' }

-- FIXME - sort into udp, tcp, udptcp catagories

-- I want hipl and sctp support built in
--[
-- udptcp.ports

-- udp.ports
-- tcp.ports
--]

ports = {
-- Interactive classs: SSH Terminal, DNS and gaming (Quake)
   ["INTERACTIVE"] = "22,222",
   ["GAMES"] = "3389,5900,5688",

-- People that use proxies can be shaped better, and 443 is important

   ["PROXY"] = "8123,3128,8118,1080,443,6127",
-- rdate?
   ["NTP"] = "123",
   ["RTP"] = "5004:5005",
   -- ichat? skype?
   -- VoIP telephony
   ["SIGNAL"] = "5060:5062",
   ["VOIP"] = "5062:5100,10000:11000,5000:5059,8000:8016,5004,1720,1731,4569",
   ["VPN"] = "1194,500,4500",
   ["CHAT"] = "6667,7000,194,5190,5222,5269",
   ["BROWSING"] = "80,81,8080",
   --FIXME: icecast, look at some radio stations. Soma and radio paradise use:
   ["A_STREAM"] = "8600,8048,9010,8884,8384,8010,9000",
   --FIXME: netflix, etc
   ["V_STREAM"] = "554",
   ["ZEBRA"] = "2600:2608",
   ["MONITOR"] = "161:162,199,5777",
   -- Routing
   ["ROUTING"] = "179,2600:2608",
   -- Yes, let's track git and cvs
   ["SCM"] = "371,2401,3690,9418",
   ["MAIL"] = "143,220,993,587,465",
   -- Rsync, SMTP
   ["BULK"] = "25,873,20:21,109:110,119,631,4559",
   -- Traditional filesharing has it's place
   ["FILE"] = "137:139,369:370,445,2049,7000:7009",
   -- The lowest priority traffic: eDonkey, Bittorrent, etc.
   ["P2P"] = "110,143,445,4662:4664,6881:6999,540,1214,4031,6346:6347",
   ["XWIN"] = "177,6000:6010,7100",
   ["DB"] = "1433:1434,3050,3306,5432:5433,5984",
   ["BACKUP"] = "9101:9103,10080,13720:13721,13782:13783,2988:2989,10081:10083",
   ["TEST"] = "5001:5002"
}

-- doesn't cost a lot to just do this

tcpports = ports
udpports = ports

ICMPV6 = {
    ["Ping"] = 128,
    ["Pong"] = 129,
    ["Neighbor Solicitation"] = 135,
    ["Neighbor Advertisement"] = 136,
    ["Dest Unreachable"] = 1,
    ["Packet Too Big"] = 2,
    ["Parameter Problem"] = 3,
    ["Router Solicitation"] = 133,
    ["Router Advertisement"] = 134,
    ["Group Membership query"] = 130,
    ["Group Membership report"] = 131,
    ["Group Membership Reduciton"] = 132,
    ["Redirect"] =137,
    ["Router Renumbering"] =138,
    ["Node info query"] = 139,
    ["Node info response"] = 140,
    ["Inverse NDS"] = 141,
    ["Inverse ADV"] = 142,
    ["MLDv2 Listener Report"] = 143,
    ["Home agent disc req"] = 144,
    ["Home agent reply"] = 145,
    ["Mobile prefix solicit"] = 146,
    ["Mobile prefix Adv"] = 147,
    ["Cert path solicit"] =148,
    ["Cert path Adv"] = 149,
    ["Experimental mobility"] = 150,
    ["MRD advertisment"] = 151,
    ["MRD Solicitation"] = 152,
    ["MRD Termination"] = 153,
    ["FMIPv6"] = 154 
}

-- We could use some shortcuts for common ipv6 addrs
-- FIXME: not sure all these are correct. 
-- I'd like to be able to use anycast right

i6 = {
   ["link-local"] = "fe80::/10",
   ["mcast"] = "ff00::/8",
   ["interface-local"] = "ff01::/12",
   ["link-local-multicast"] = "ff02::/12",
   ["admin-local"] = "ff04::/12",
   ["site-local"] = "ff05::/12",
   ["organization-local"] = "ff08::/12",
   ["unspecified"] = "::/128",
   ["default-route"] = "::/0",
   ["loopback"] = "::1/128",
   ["default-route"] = "::/0",
   ["unique-local"] = "fc00::/7",
   ["ipv4-mapped"] = "::ffff:0:0/96",
   ["ipv4-translated"] = "::ffff:0:0:0/96",
   ["well-known"] = "64:ff9b::/96",
   ["6to4"] = "2002::/16",
   ["teredo"] = "2001::/32",
   ["BMWG"] = "2001:2::/48",
   ["ORCHID"] = "2001:10::/28",
   ["documentation"] = "2001:db8::/32"
}
-- 
-- Syntax is a:b,c,d,e,f:g
-- a:b counts as two entries

function proto_split(s,max)
   s = { }
   c = 1
   t = split(',',s)
   p = 0
   for i,v in ipairs(t) do
      p = # split(':',v)
      c = c + p
      if c > max then 
	 n = n + 1
	 s[n] = v 
	 c = p
      else 
	 s[n] = s[n] .. v 
	 c = c + 1
      end
   end
   return(s)
end
