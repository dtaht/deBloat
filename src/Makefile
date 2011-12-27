NET:=/etc/network
all: 
	@echo make install will put the qfq version of this into your network

install:
	cp staqfq.lua $(NET)/if-pre-up.d/debloat
	chmod a+rx $(NET)/if-pre-up.d/debloat

clean:
	rm $(NET)/if-pre-up.d/debloat
