CUT=extract.timeseries.awk
CUT2=extract.timeseries400.awk
plotR=plotit.R
plotR1=plot1.R
plotR400=plot400.R

all: plot.ps plot1.ps plot400.ps plot400-1.ps

%.ts.cut: %.txt $(CUT)
	sed 's/=/ /g' $< | awk -f $(CUT) > $@

%.ts.cut.400: %.txt $(CUT2)
	sed 's/=/ /g' $< | awk -f $(CUT2) > $@

plot.ps: $(plotR) p1.ts.cut p2.ts.cut
	R --vanilla < $<

plot1.ps: $(plotR1) p1.nodup.ts.cut p2.nodup.ts.cut
	R --vanilla < $<

plot400.ps: $(plotR400) p1.ts.cut.400 p2.ts.cut.400
	R --vanilla < $<

plot400-1.ps: $(plotR1) p1.nodup.ts.cut.400 p2.nodup.ts.cut.400
	R --vanilla < $<

clean:
	rm *.cut *.ps
