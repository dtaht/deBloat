# Basic victory here

set terminal png nocrop enhanced font arial 8 size 1000,1000
set output 'ab.1.png'
set dummy t,y
set format x "%3.2f"
set format y "%3.2f"
set format z "%3.2f"
unset key 
set parametric
set samples 100, 100
set style function dots
set title "Ping RTT under load"
set xlabel "RTT"
set xrange [ 0.00000 : 30.00000 ] noreverse nowriteback
set ylabel "Time"
set yrange [ 0.00000 : 100.00000 ] noreverse nowriteback
set datafile separator ','
plot "ab.csv" using 2:1 title 'localhost', "ab2.csv" using 2:1 title 'next hop'
