# Functions for classifying packets into Ants, MICE, and Elephants

# Note: full ipv6 support requires a netfilter patch for ecn
# Also, there a bug that completely disables ipv6 tos handling
# in netfilter... and I'm still not confident it's actually fixed
# fixed in 2.6.39 commit 1ed2f73d90fb49bcf5704aee7e9084adb882bfc5


recreate_filter() {
    local iptables=$1
    local filter=$2
    local chain=$3
    $iptables -t $filter -F $chain 2> $DEBUG_LOG
    $iptables -t $filter -X $chain 2> $DEBUG_LOG
    $iptables -t $filter -N $chain 2> $DEBUG_LOG
}

# On site ingress, stomp on the existing DSCP bits
# A saner policer might try to at least preserve the EF
# bits, and merely stomp on LB and CS7 bits

# Note that *not* doing this introduces a problem (again) with ssh
# interactive traffic and also vpns.

site_ingress() {
    local IFACE=$1
    local iptables
    for iptables in iptables ip6tables
    do
	$iptables -i $IFACE -A INGRESS -m dscp --dscp-class $LB -j DSCP --set-dscp-class BE
	$iptables -i $IFACE -A INGRESS -m dscp --dscp-class CS7 -j DSCP --set-dscp-class BE
	# There is no easy way to mark codepoints that you aren't using back 
	# into something sane. A syntax like ! --dscp-map-class CP,CP,CP,CP,CP
	# would be helpful, as with a single 64 bit mask we could reclassify
	# something in 2 rules rather than 64
	# (also useful would be to use unassigned codepoints above, too)
	# It is very amusing most web traffic is CS1
	# So we drop everything else into a BE catagory 
	# processing, for now...
	for i in $UNKNOWN_CODEPOINTS
	do
	$iptables -i $IFACE -A INGRESS -m dscp --dscp $i -j DSCP --set-dscp-class BE
	done
    done
}

# I thought it would be interesting to see what the beleagured
# sysadmins of the world were doing to try and wedge every form
# of communication through port 80 so I wrote this.
# It turned out that nearly all web traffic was not BE, but CS1.

# In the future...
# It may be useful to allow certain classes in without filtering.

p80_rathole() {
    local iptables=$1
    recreate_filter $iptables mangle P80RATHOLE 
    for i in `seq 0 63`
    do
	$iptables -t mangle -A P80RATHOLE -m dscp --dscp $i \
	    -m recent --name p80_$i --set
    done
}

dscp_WEB() {
    local iptables=$1
    recreate_filter $iptables mangle SWEB
    recreate_filter $iptables mangle TESTS
    recreate_filter $iptables mangle WEB

# if the vast majority of websites out there want to classify
# as bulk, let them.
# Arguably allowing a range here would be good.

    [ "$p80_stats" = "1" ] && p80_rathole $iptables
    [ "$p80_stats" = "1" ] && $iptables -t mangle -A WEB -j P80RATHOLE

    $iptables -t mangle -A WEB -m dscp ! --dscp-class CS1 -j DSCP \
        --set-dscp-class AF22 \
	-m comment --comment 'Bulk BROWSING'
    $iptables -t mangle -A WEB -m dscp --dscp-class CS1 -j DSCP \
        --set-dscp-class AF23 \
	-m comment --comment 'BE BROWSING'
    $iptables -t mangle -A SWEB -j DSCP --set-dscp-class AF21 \
	-m comment --comment 'Proxies/433'
    $iptables -t mangle -A TESTS -j DSCP --set-dscp-class CS1 -m comment \
	    --comment 'Bandwidth Tests'
}

# I am not sure why I used tcp and udp distinctions. 
# would probably have been saner in many cases
# FIXME: Do other protocols (41,50,51,58) Be thorough.

classify() {
    local iptables
    for iptables in iptables ip6tables
    do
	recreate_filter $iptables mangle STATS_ECN
	recreate_filter $iptables mangle BIMODAL
	recreate_filter $itpables mangle SYN_EXPEDITE
	recreate_filter $iptables mangle Ants_END
	recreate_filter $iptables mangle Ants
	recreate_filter $iptables mangle D_CLASSIFIER_END
	recreate_filter $iptables mangle D_CLASSIFIER 

# I'm not certain this is a good idea, but the initial syn and syn/ack is a mouse.
# as are fins and fin/acks, sorta. And we usually do interesting stuff on syns

	$iptables -t mangle -A SYN_EXPEDITE -p tcp -m tcp --syn -j DSCP \
	    --set-dscp-class AF11 -m comment --comment 'Expedite new connections' 
	$iptables -t mangle -A SYN_EXPEDITE -p tcp -m tcp --tcp-flags ALL SYN,ACK -j DSCP \
	    --set-dscp-class AF11 -m comment --comment 'Expedite new connection ack' 

# FIXME: Maybe make ECN enabled streams mildly higher priority. 
# This just counts the number of ECN and non-ECN streams
# FIXME: Also mark against IP not TCP

	$iptables -t mangle -A STATS_ECN -p tcp -m tcp \
	    --tcp-flags ALL SYN,ACK -m ecn --ecn-tcp-ece -m recent \
	--name ecn_enabled --set -m comment --comment 'ECN enabled' 
	$iptables -t mangle -A STATS_ECN -p tcp -m tcp \
	    --tcp-flags ALL SYN,ACK -m ecn ! --ecn-tcp-ece -m recent \
	    --name ecn_disabled --set -m comment --comment 'ECN disabled' 

# FIXME: SSH rule needs to distinguish between interactive and bulk sessions
# Actually simply codifying current practice (0x04) would be
# Better. Call it the 'IT' field. Interactive Text. BOFH works too.

# So we need match if the interactive bit is set
# And if not set, toss it in bulk

# FIXME: maybe be more clever here and just check for interactive bit
#        rather than the whole field

	$iptables -t mangle -A BIMODAL -p tcp -m tcp -m multiport \
	    --ports $INTERACTIVEPORTS -m dscp --dscp $BOFH \
	    -m comment --comment 'SSH Interactive'

	$iptables -t mangle -A BIMODAL -p tcp -m tcp -m multiport \
	    --ports $INTERACTIVEPORTS -m dscp ! --dscp $BOFH \
	    -j DSCP --set-dscp-class CS1 \
	    -m comment --comment 'SSH Bulk'

# FIXME: Multiple other flows are also bimodal

# not sure if this matches dhcp actually
# And we should probably have different classes for multicast vs non multicast
# Wedging all these ants into the CS6 catagory is probably a bit much

	$iptables -t mangle -A Ants -p udp -m multiport --ports 53,67,68 \
	    -j DSCP --set-dscp $ANT -m comment \
	    --comment 'DNS, DHCP, are very important' 
	$iptables -t mangle -A Ants -p udp -m multiport --ports $SIGNALPORTS \
	    -j DSCP --set-dscp-class CS5 -m comment \
	    --comment 'VOIP Signalling'
	$iptables -t mangle -A Ants -p udp -m multiport --ports $VOIPPORTS,$NTPPORTS \
	    -j DSCP --set-dscp-class EF -m comment --comment 'VOIP'
	$iptables -t mangle -A Ants -p udp -m multiport --ports $GAMINGPORTS \
	    -j DSCP --set-dscp-class CS4 -m comment --comment 'Gaming'
	$iptables -t mangle -A Ants -p udp -m multiport --ports $MONITORPORTS \
	    -j DSCP --set-dscp-class CS2 -m comment --comment 'SNMP'

	if [ "$iptables" = "ip6tables" ]
	then
# addrtype for ipv6 isn't compiled in by default
# Perhaps tracking ICMP is important
	    $iptables -t mangle -A Ants -s fe80::/10 -d fe80::/10 \
		-j DSCP --set-dscp $ANT \
		-m comment --comment 'Link Local sorely needed'
	    $iptables -t mangle -A Ants -d ff00::/12 \
		-j DSCP --set-dscp-class AF43 \
		-m comment --comment 'Multicast far less needed'
	    $iptables -t mangle -A Ants -s fe80::/10 -d ff00::/12 \
		-j DSCP --set-dscp $ANT \
		-m comment --comment 'But link local multicast is good'

# And we really want babel and ahcp to try to get through
	    $iptables -t mangle -A Ants -s fe80::/10 -d ff00::/12 \
		-p udp \
		-m multiport --port 6697,5359 \
		-j DSCP --set-dscp-class CS6 \
		-m comment --comment 'Babel, AHCP'

# FIXME: Multicast ntp is also important. multicast address?
# FIXME: Perhaps we can downshift after multiple hops

	    $iptables -t mangle -A Ants -d ff00::/12 \
		-p udp \
		-m multiport --port 123 \
		-j DSCP --set-dscp-class CS6 \
		-m comment --comment 'Multicast NTP'

# As is neighbor discovery, etc, but I haven't parsed 
# http://tools.ietf.org/html/rfc4861 well yet
# $iptables -t mangle -A Ants -s fe80::/10 -d ff00::/12 \
# -j DSCP --set-dscp-class AF12 -m comment 
# --comment 'ND working is good too' \
# As for other forms of icmp, don't know
	else
#didn't work
#$iptables -t mangle -A Ants -m addrtype --dst-type MULTICAST 
#-j DSCP --set-dscp-class AF22 -m comment --comment 'Multicast'
#Some forms of multicast are good, others bad, but for now...
	    $iptables -t mangle -A Ants -m pkttype --pkt-type MULTICAST \
		-j DSCP --set-dscp-class AF43 \
		-m comment --comment 'Multicast'
# Arp replies? DHCP replies?
fi

# Main stuff

	$iptables -t mangle -A D_CLASSIFIER ! -p tcp -g Ants

# 98% of traffic these days is on the web
# FIXME: Actually reclassifying web traffic needs a new idea

	dscp_WEB $iptables

# This set of rules cuts performance down to less that 50Mbit/sec
# for the bottommost rules. Since we're trying to get to where we
# have CPU left over AND can see bufferbloat, do the test match first

	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $TESTPORTS -g TESTS \

	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $BROWSINGPORTS -g WEB -m comment --comment 'BROWSING'

	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $PROXYPORTS -g SWEB \
	    -m comment --comment 'Proxies/433'

# Making everything walk all this is bad, and we need to be cleverer
# about traffic coming from the machine itself

# SSH is bimodal inside a connection

	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $INTERACTIVEPORTS -g BIMODAL -m comment --comment 'SSH'
# CS4 for Xwin almost makes sense
	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $XWINPORTS -j DSCP --set-dscp-class CS4 \
	    -m comment --comment 'Xwindows'
	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $GAMINGPORTS -j DSCP --set-dscp-class CS4 \
	    -m comment --comment 'Gaming'
# FIXME: Routing takes place over many protocols
	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $ROUTINGPORTS -j DSCP --set-dscp-class CS6 \
	    -m comment --comment 'Routing'

# Arguably want a better class for git. Bulk?
	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $SCMPORTS -j DSCP --set-dscp-class AF13 \
	    -m comment --comment 'SCM'

	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $DBPORTS -j DSCP --set-dscp-class AF12 \
	    -m comment --comment 'DB'
	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $V_STREAMINGPORTS -j DSCP --set-dscp-class AF43 \
	    -m comment --comment 'Video Streaming'
# It would be nice if network radio had not gone port 80, AF3X
	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $A_STREAMINGPORTS -j DSCP --set-dscp-class AF41 \
	    -m comment --comment 'Internet Radio'
	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $FILEPORTS -j DSCP --set-dscp-class AF22 \
	    -m comment --comment 'Normal File sharing'
	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $MAILPORTS -j DSCP --set-dscp-class AF32 \
	    -m comment --comment 'MAIL clients'
# FIXME: we really want backups to take precedence over more traffic
	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $BACKUPPORTS -j DSCP --set-dscp-class CS3 \
	    -m comment --comment 'Backups'
	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $BULKPORTS -j DSCP --set-dscp-class CS1 \
	    -m comment --comment 'BULK'
# There is no codepoint for torrent. Perhaps we need to invent one
	$iptables -t mangle -A D_CLASSIFIER -p tcp -m tcp -m multiport \
	    --ports $P2PPORTS -j DSCP --set-dscp $P2P -m comment \
	    --comment 'P2P'

# I like the concept of ENC - expedite new connections.
# Syn and syn/acks are mice and dropping them hurts... but 
# It needs a little more thought.
# For example, a 32k bucket for new connections would likely be
# larger than ever needed by most anybody, and a hard limiter
# kind of good...

# A problem lies in so mangling the outgoing packet
# which may think the DSCP class is the requested one, and keep it.

# Also a codepoint for this would be something like CS4 + MMC

#	$iptables -t mangle -A D_CLASSIFIER_END -p tcp -m tcp --syn -j DSCP \
#	    --set-dscp-class AF21 -m comment --comment 'Expedite new connections' 
#	$iptables -t mangle -A D_CLASSIFIER_END -p tcp -m tcp \
#	    --tcp-flags ALL SYN,ACK -j DSCP --set-dscp-class AF21 \
#	    -m comment --comment 'Expedite new connection ack' 

# FIXME: Maybe make ECN enabled streams mildly higher priority. 
# This just counts the number of ECN and non-ECN streams

	$iptables -t mangle -A D_CLASSIFIER_END -p tcp -m tcp \
	    --tcp-flags ALL SYN,ACK -m ecn --ecn-tcp-ece -m recent \
	    --name ecn_enabled --set -m comment --comment 'ECN enabled streams' 
	$iptables -t mangle -A D_CLASSIFIER_END -p tcp -m tcp \
	    --tcp-flags ALL SYN,ACK -m ecn ! --ecn-tcp-ece -m recent \
	    --name ecn_disabled --set -m comment --comment 'ECN disabled streams' 

done
}

# Ya know, I care about ipv6. Nobody else does
# This could be more detailed, but right now...

icmpv6() {
    recreate_filter ip6tables mangle C_ICMP6
    ip6tables -t mangle -A C_ICMP6 -p icmpv6 -m comment --comment 'ICMPv6 ANT' -j DSCP --set-dscp $ANT 
}

# More or less sorted by frequency

icmpv6_stats() {
    recreate_filter ip6tables filter ICMP6_STATS
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 128 -m comment --comment 'ping' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 129 -m comment --comment 'pong' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 135 -m comment --comment 'Neighbor Solicitation' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 136 -m comment --comment 'Neighbor Advertisement' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 1 -m comment --comment   'dest unreachable' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 2 -m comment --comment   'packet too big' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 3 -m comment --comment   'parameter problem' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 133 -m comment --comment 'Router Solicitation' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 134 -m comment --comment 'Router Advertisement' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 130 -m comment --comment 'Group Membership query' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 131 -m comment --comment 'Group Membership report' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 132 -m comment --comment 'Group Membership Reduciton' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 137 -m comment --comment 'Redirect' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 138 -m comment --comment 'Router Renumbering' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 139 -m comment --comment 'Node info query' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 140 -m comment --comment 'Node info response' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 141 -m comment --comment 'Inverse NDS' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 142 -m comment --comment 'Inverse ADV' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 143 -m comment --comment 'MLDv2 Listener Report' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 144 -m comment --comment 'Home agent disc req' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 145 -m comment --comment 'Home agent reply' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 146 -m comment --comment 'Mobile prefix solicit' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 147 -m comment --comment 'Mobile prefix Adv' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 148 -m comment --comment 'Cert path solicit' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 149 -m comment --comment 'Cert path Adv' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 150 -m comment --comment 'Experimental mobility' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 151 -m comment --comment 'MRD advertisment' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 152 -m comment --comment 'MRD Solicitation' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 153 -m comment --comment 'MRD Termination' -j RETURN
    ip6tables -A ICMP6_STATS -p icmpv6 --icmpv6-type 154 -m comment --comment 'FMIPv6' 
}

# Classify Diffserv marked packets into the right 802.11e buckets
# I think I need to set the skb priority field using tc however
# this sets marks which aren't the same thing.


# const int ieee802_1d_to_ac[8] = {
#         IEEE80211_AC_BE, 0
#         IEEE80211_AC_BK, 1
#         IEEE80211_AC_BK, 2
#         IEEE80211_AC_BE, 3
#         IEEE80211_AC_VI, 4
#         IEEE80211_AC_VI, 5
#         IEEE80211_AC_VO, 6
#         IEEE80211_AC_VO  7
# };

# E and D can be the same, actually

# FIXME: These theoretically are priority << 13, don't match with 
# the fixed stuff in the vlan kernel

mac8021q() {
    local iptables
    for iptables in iptables ip6tables
    do
    recreate_filter $iptables mangle W8021q
    $iptables -t mangle -A W8021q -j CLASSIFY --set-class 0:103 -m comment --comment                            'Reclassify BE'
    $iptables -t mangle -A W8021q -m dscp --dscp-class EF -j CLASSIFY   --set-class 0:107 -m comment --comment  'Voice (VO)(EF)'
    $iptables -t mangle -A W8021q -m dscp --dscp-class CS6 -j CLASSIFY  --set-class 0:106 -m comment --comment  'Critical (VO)'
    $iptables -t mangle -A W8021q -m dscp --dscp $ANT -j CLASSIFY       --set-class 0:105 -m comment --comment  'Ants(VI)'
    $iptables -t mangle -A W8021q -m dscp --dscp $BOFH -j CLASSIFY      --set-class 0:105 -m comment --comment  'Typing (VI)'
    $iptables -t mangle -A W8021q -m dscp --dscp-class AF41 -j CLASSIFY --set-class 0:104 -m comment --comment  'Net Radio(VI)'
    $iptables -t mangle -A W8021q -m dscp --dscp-class CS3 -j CLASSIFY  --set-class 0:104 -m comment --comment  'Video (VI)'
    $iptables -t mangle -A W8021q -m dscp --dscp-class CS1 -j CLASSIFY  --set-class 0:102 -m comment --comment  'Background (BK)'
    $iptables -t mangle -A W8021q -m dscp --dscp-class CS5 -j CLASSIFY  --set-class 0:101 -m comment --comment  'General Stuff (BK)'
    $iptables -t mangle -A W8021q -m dscp --dscp $P2P -j CLASSIFY       --set-class 0:101 -m comment --comment  'P2P (BK)'
    $iptables -t mangle -A W8021q -m dscp --dscp-class CS2 -j CLASSIFY  --set-class 0:102 -m comment --comment  'Background (BK)'
    $iptables -t mangle -A W8021q -m dscp --dscp-class AF33 -j CLASSIFY --set-class 0:102 -m comment --comment  'Background (AF33)'
    done
}

# FIXME
mac80211e() {
    local iptables
    for iptables in iptables ip6tables
    do
    recreate_filter $iptables mangle W80211e
    $iptables -t mangle -A W80211e -j CLASSIFY --set-class 0:3 -m comment --comment                            'Reclassify BE'
    $iptables -t mangle -A W80211e -m dscp --dscp-class EF -j CLASSIFY   --set-class 0:1 -m comment --comment  'Voice (VO)(EF)'
    $iptables -t mangle -A W80211e -m dscp --dscp-class CS6 -j CLASSIFY  --set-class 0:2 -m comment --comment  'Critical (VO)'
    $iptables -t mangle -A W80211e -m dscp --dscp $ANT -j CLASSIFY       --set-class 0:2 -m comment --comment  'Ants(VI)'
    $iptables -t mangle -A W80211e -m dscp --dscp $BOFH -j CLASSIFY      --set-class 0:2 -m comment --comment  'Typing (VI)'
    $iptables -t mangle -A W80211e -m dscp --dscp-class AF41 -j CLASSIFY --set-class 0:2 -m comment --comment  'Net Radio(VI)'
    $iptables -t mangle -A W80211e -m dscp --dscp-class CS3 -j CLASSIFY  --set-class 0:2 -m comment --comment  'Video (VI)'
    $iptables -t mangle -A W80211e -m dscp --dscp-class CS1 -j CLASSIFY  --set-class 0:3 -m comment --comment  'Background (BK)'
    $iptables -t mangle -A W80211e -m dscp --dscp-class CS5 -j CLASSIFY  --set-class 0:3 -m comment --comment  'General Stuff (BK)'
    $iptables -t mangle -A W80211e -m dscp --dscp $P2P -j CLASSIFY       --set-class 0:3 -m comment --comment  'P2P (BK)'
    $iptables -t mangle -A W80211e -m dscp --dscp-class CS2 -j CLASSIFY  --set-class 0:3 -m comment --comment  'Background (BK)'
    $iptables -t mangle -A W80211e -m dscp --dscp-class AF33 -j CLASSIFY --set-class 0:3 -m comment --comment  'Background (AF33)'
    done
}


# This attempts to keep track of DSCP classified packets in one chain.
# It's sorted by frequency of occurence to mimimize overhead
# -j RETURN might make more sense
# It would be cooler if this was on a per device basis.

dscp_stats() {
    local iptables
    for iptables in iptables ip6tables
    do
    recreate_filter $iptables filter DSCP_STATS
    
# this first doesn't belong here.
    
#   $iptables -t filter -A DSCP_STATS -p udp -m multiport --ports $VPNPORTS -m comment --comment  'VPN' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class BE   -m comment --comment 'BE'   -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class CS1  -m comment --comment 'CS1'  -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class CS6  -m comment --comment 'CS6'  -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp $BOFH      -m comment --comment 'BOFH' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp $ANT       -m comment --comment 'ANT'  -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class EF   -m comment --comment 'EF'   -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF21 -m comment --comment 'AF21' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF22 -m comment --comment 'AF22' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF23 -m comment --comment 'AF23' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp $P2P       -m comment --comment 'P2P'  -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF41 -m comment --comment 'AF41' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class CS7  -m comment --comment 'CS7'  -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class CS5  -m comment --comment 'CS5'  -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class CS4  -m comment --comment 'CS4'  -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class CS3  -m comment --comment 'CS3'  -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class CS2  -m comment --comment 'CS2'  -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF42 -m comment --comment 'AF42' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF43 -m comment --comment 'AF43' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF11 -m comment --comment 'AF11' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF12 -m comment --comment 'AF12' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF13 -m comment --comment 'AF13' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF31 -m comment --comment 'AF31' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF32 -m comment --comment 'AF32' -j RETURN
    $iptables -t filter -A DSCP_STATS -m dscp --dscp-class AF33 -m comment --comment 'AF33' -j RETURN
# Some non-standardized classifications
    $iptables -t filter -A DSCP_STATS -m dscp --dscp $LB -m comment --comment 'LB' -j RETURN
    $iptables -t filter -A DSCP_STATS -m comment --comment 'Unmatched' -j LOG
    done
}

reset() {
:
}

# The only way I know how to cope with this is brute force

clean() {
	ip6tables -t filter -F
	ip6tables -t mangle -F
	iptables -t filter -F
	iptables -t mangle -F
	iptables -t raw -F

#	iptables -t nat -F

	ip6tables -t filter -X
	ip6tables -t mangle -X
	iptables -t filter -X
	iptables -t mangle -X
	iptables -t raw -X

}

# Send various interfaces to last classifier

addoifs() {
    local iptables=$1
    local table=$2
    local chain=$3
    local target=$4
    local devs="$5"
    for d in $devs
    do
	$iptables -t $table -A $chain -o $d -j $target
    done
}

finalize() {
    for iptables in iptables ip6tables
    do
# Not quite convinced this is right
	recreate_filter $iptables mangle SYNS
# FIXME: Expedite has issues at this layer
#	$iptables -t mangle -A SYNS -j SYN_EXPEDITE 

	[ "$ecn_stats" = 1 ] && { 
	$iptables -t mangle -A SYNS -j STATS_ECN
	}
	$iptables -t mangle -A PREROUTING -j SYNS
	$iptables -t mangle -A OUTPUT -j SYNS
	$iptables -t mangle -A PREROUTING -j D_CLASSIFIER
	$iptables -t mangle -A OUTPUT -j D_CLASSIFIER

# Not clear I have to treat ICMPv6 specially but...
	if [ $iptables = "ip6tables" ] 
	then
             ip6tables -t mangle -A OUTPUT -p 58 -s fe80::/10 -j C_ICMP6
             ip6tables -t mangle -A FORWARD -p 58 -s fe80::/10 -j C_ICMP6
	fi
	addoifs $iptables mangle OUTPUT W80211e "$WIRELESS_DEVS"
	addoifs $iptables mangle FORWARD W80211e "$WIRELESS_DEVS"
	addoifs $iptables mangle OUTPUT W8021q "$WIRED_DEVS"
	addoifs $iptables mangle FORWARD W8021q "$WIRED_DEVS"
 	[ "$dscp_stats" = 1  ] && { 
	$iptables -A OUTPUT -j DSCP_STATS
	$iptables -A FORWARD -j DSCP_STATS
	}
    done
 	[ "$icmp6_stats" = "1"  ] && { 
	ip6tables -A OUTPUT -p 58 -j ICMP6_STATS 
	ip6tables -A FORWARD -p 58 -j ICMP6_STATS
	}
}

start() {
    clean
    icmpv6
    icmpv6_stats
    dscp_stats
    classify
    mac80211e
    mac8021q
    finalize
}

stop() {
clean
}

restart() {
    stop
    start
}

status4() {
    iptables -x -v -n -L DSCP_STATS
}

status6() {
    ip6tables -x -v -n -L DSCP_STATS
    ip6tables -x -v -n -L ICMP6_STATS
}

status() {
    echo "IPV6 Stats"
    status6
    echo "IPV4 Stats"
    status4
}

help() {
:
}
