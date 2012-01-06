set title 'SFQ from router 1 to router 2 - 10 iperfs'
set timestamp bottom
set key on inside center box title 'PING RTT'
set yrange [0:1]
set xrange [1.4:1.8]
set ylabel 'Probability'
set xlabel 'RTT MS'
plot '/tmp/org-plot4180pBB' u 2:(1./600.) smooth cumulative title 'r1', \
'/tmp/org-plot4180pBB' u 3:(1./600.) smooth cumulative title 'r2' 
