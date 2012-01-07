set title "Latency of ping vs 200 netperf\n SFQ as tested on Erics box"
set timestamp bottom
set key on inside center box title 'PING RTT (log scale)'
set yrange [0.05:1]
set xrange [0.1:1.1]
set logscale x 10
set ylabel 'Probability'
set xlabel 'RTT MS'
plot 'idle.data' u 2:(1./20.) smooth cumulative title 'IDLE', \
'loaded.data' u 2:(1./20.) smooth cumulative title 'NEWEST SFQ', \
'no_tso.data' u 2:(1./20.) smooth cumulative title 'NEW SFQ NO TSO', \
'tso.data' u 2:(1./20.) smooth cumulative title 'NEW SFQ With TSO'
