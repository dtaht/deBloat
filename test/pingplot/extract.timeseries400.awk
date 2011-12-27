BEGIN {
    ERR = "/dev/stderr"
    timeout_offset = 100.00
}

/timeout/ {
#    rtt[NR] = "max"    
    next
}

/DUP/ {
#    rtt[NR] = "max"    
    next
}

{#
    if ($10 > 400) 
	rtt[NR] = -1
    else 
        rtt[NR] = $10  
    if ($10 > max_rtt) {
	max_rtt = $10
	max_rtt_nr = NR
    }
}

END {
    print "max:", max_rtt, "at:", max_rtt_nr > ERR
    
    if ( (max_rtt_nr - 100) < 0 )
	start = 1
    else
	start = max_rtt_nr - 100

    if ( (max_rtt_nr + 100) > NR )
	stop = NR
    else
	stop = max_rtt_nr + 100

    for ( i = start; i <= stop; i ++) {
	if (rtt[i] == "max")
	    rtt[i] = max_rtt + timeout_offset
	print rtt[i]
    }
}
