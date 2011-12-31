# This is an example from the web on how to do multiple plots on one 
# page
set terminal png transparent nocrop enhanced font arial 8 size 420,320 
set output 'margins.1.png'
set bar 1.000000
set style rectangle back fc lt -3 fillstyle  solid 1.00 border -1
unset key
set view map
set samples 50, 50
set isosamples 50, 50
set noytics
set rrange [ * : * ] noreverse nowriteback  # (currently [0.00000:10.0000] )
set trange [ * : * ] noreverse nowriteback  # (currently [-5.00000:5.00000] )
set urange [ -15.0000 : 15.0000 ] noreverse nowriteback
set vrange [ -15.0000 : 15.0000 ] noreverse nowriteback
set xrange [ -15.0000 : 15.0000 ] noreverse nowriteback
set ylabel  offset character 0, 0, 0 font "" textcolor lt -1 rotate by 90
set y2label  offset character 0, 0, 0 font "" textcolor lt -1 rotate by 90
set yrange [ * : * ] noreverse nowriteback  # (currently [-15.0000:15.0000] )
set zrange [ -0.250000 : 1.00000 ] noreverse nowriteback
set cblabel  offset character 0, 0, 0 font "" textcolor lt -1 rotate by 90
set lmargin at screen 0.2
set bmargin at screen 0.1
set rmargin at screen 0.85
set tmargin at screen 0.25
set locale "C"
f(h) = sin(sqrt(h**2))/sqrt(h**2)
y = 0
plot sin(sqrt(x**2+y**2))/sqrt(x**2+y**2)
