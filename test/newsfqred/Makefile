# convert ping format to something gnuplot can deal with

%.data : %.ping
	./parse $< > $@

# FIXME - output pngs
GNUPLOT = /usr/bin/gnuplot
GNUPLOTI = /usr/bin/gnuplot
PAUSE=pause.plt
PNGOUT=png.plt
PSOUT=ps.plt

OBJ:=$(wildcard *.data)
PNG:=$(OBJ:.data=.png)
PS:=$(OBJ:.data=.ps)
GRAPHS:=$(wildcard *.ps *.png)

logscale=ericpinglog.plt
normscale=ericping.plt

all: $(OBJ) ping.png ping.ps ping_log.ps ping_log.png

pingl: $(OBJ)
	cat $(logscale) $(PAUSE) | $(GNUPLOTI)

ping: $(OBJ)
	cat $(normscale) $(PAUSE) | $(GNUPLOTI)

ping_log.png: $(OBJ)
	cat $(PNGOUT) $(logscale) | $(GNUPLOT) > ping_log.png

ping.png: $(OBJ)
	cat $(PNGOUT) $(normscale) | $(GNUPLOT) > ping.png

ping_log.ps: $(OBJ)
	cat $(PSOUT) $(logscale) | $(GNUPLOT) > ping_log.ps

ping.ps: $(OBJ)
	cat $(PSOUT) $(normscale) | $(GNUPLOT) > ping.ps

clean: $(OBJ)
	rm -f $(PS) $(PNG) $(GRAPHS)
