set title "5ghz Wireless Latency distribution of fping -b 220\n10ms period vs 50 iperfs \nREDSFQ"
set timestamp bottom
set key on inside bottom box title 'PING RTT'
set yrange [0:1]
set xrange [4:80]
set ylabel 'Probability'
set xlabel 'RTT MS'
plot 'fpingsample.data' u 2:(1./4281.) smooth cumulative title 'Wireless Latency under load'
