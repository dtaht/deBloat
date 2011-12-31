set term tikz standalone color solid size 5in,3in
set output "sin.tex"
set xrange [0:2*pi]
plot sin(x) with lines
exit
