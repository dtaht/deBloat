set title "SFQRED w/head of queue patch vs Old SFQRED \n1s ping period vs 2 netperfs each in BE,EF,BK bins\nREDSFQ\n 2Mbit uplink (simulated)"
set timestamp bottom
set key on inside bottom box title 'PING RTT'
set yrange [0:1]
set xrange [19:59]
set ylabel 'Probability'
set xlabel 'RTT MS'
plot 'newsfq2.data' u 2:(1./100.) smooth cumulative title 'HoQ SFQRED under load', 'oldsfq2.data' u 2:(1./100.) smooth cumulative title 'SFQRED under load'
