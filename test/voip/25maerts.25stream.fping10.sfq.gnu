set title '25 MAERTS, 25 STREAMS, 1 TCP_RR, FPING 10ms\n OLD SFQ across 2 routers'
set timestamp bottom
set key on inside center box title 'PING RTT'
set yrange [0:.6]
set xrange [.2:1]
set xlabel 'RTT MS'
plot '25maerts.25stream.fping10.pfifo.txt' u 2:(1./8000.) smooth cumulative title 'PFIFO', \
'25maerts.25stream.fping10.sfq.txt' u 2:(1./8000.) smooth cumulative title 'NEW SFQ', \
'25maerts.25stream.fping10.qfq.txt' u 2:(1./8000.) smooth cumulative title 'QFQ DROP_HEAD'
pause 500
