set title "New SFQ vs SFQ Enqueue to Head\n SFQRED"
set timestamp bottom
set key on inside bottom box title 'PING RTT'
set yrange [0:50]
set xrange [1:100]
set ylabel 'RTT MS'
set xlabel 'TIME'
plot 'newsfq2.data' u 2 title 'NEW', 'oldsfq2.data' u 2 title 'OLD'

