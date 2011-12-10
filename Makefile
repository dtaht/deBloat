SUBDIRS:=debianstuff src

all: 
	cd debianstuff; make all
	cd src; make all

install: 
	cd debianstuff; make all
	cd src; make all

clean: 
	cd debianstuff; make all
	cd src; make all

