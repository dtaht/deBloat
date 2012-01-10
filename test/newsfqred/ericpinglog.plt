set title "Wireless 5ghz Latency of ping vs 50 iperf\n SFQRED"
set timestamp bottom
set key on inside bottom box title 'PING RTT (log scale)'
set yrange [0.05:240]
set xrange [1:10000]
set logscale y 10
set ylabel 'RTT MS'
set xlabel 'TIME'
plot 'fpingflows.data' u 2 title '10000 fpings'
