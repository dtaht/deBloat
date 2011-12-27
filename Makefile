SUBDIRS:=debianstuff src

all: 
	cd debianstuff; make all
	cd src; make all

install: 
	cd debianstuff; make install
	cd src; make install

clean: 
	cd debianstuff; make clean
	cd src; make clean

