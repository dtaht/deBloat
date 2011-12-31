set terminal png nocrop enhanced font arial 8 size 1000,1000
set output 'ping.1.png'
set dummy t,y
set format x "%3.2f"
set format y "%3.2f"
set format z "%3.2f"
unset key 
set parametric
set samples 1000, 1000
set style function dots
set title "Ping RTT under load"
set xlabel "RTT"
set xrange [ 0.00000 : 4.00000 ] noreverse nowriteback
set ylabel "Time"
set yrange [ 0.00000 : 60.00000 ] noreverse nowriteback
set zlabel "rand(n + 2) ->"
set zrange [ 0.00000 : 1.00000 ] noreverse nowriteback
set datafile separator ','
plot 'test.csv'

