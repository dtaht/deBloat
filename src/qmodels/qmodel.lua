-- base class for qdiscs

module(...,package.seeall)

params = { IFACE, MACHINES, BINS, PLIMIT, BLIMIT, TLIMIT,
	   UPLINK, DOWNLINK, MTU, 
	   MAX_BINS, MAX_BLIMIT, MAX_PLIMIT  }

defaults = { ["MAX_BINS"] = 8192,
	     ["MAX_BLIMIT"] = 64000 }
