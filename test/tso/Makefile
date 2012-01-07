# convert ping format to something gnuplot can deal with

%.data : %.ping
	./parse $< > $@

# FIXME - output pngs
GNUPLOT = /usr/bin/gnuplot
GNUPLOTI = /usr/bin/gnuplot
# GNUPLOT = /usr/bin/gnuplot -e 'set terminal something other than this'
SRC:=$(wildcard *.ping)
OBJ:=$(SRC:.ping=.data)
PNG:=$(SRC:.data=.png)
logscale=ericpinglog.plt
normscale=ericping.plt

all: $(OBJ) 

pingl: $(OBJ)
	$(GNUPLOTI) < $(logscale)

ping: $(OBJ)
	$(GNUPLOTI) < $(normscale)

ping_log.png: $(OBJ)
	$(GNUPLOT) < $(logscale)

ping.png: $(OBJ)
	$(GNUPLOT) < $(normscale)

clean: $(OBJ)
	rm -f $(OBJ) 
