#include <stdio.h>
#include <stdlib.h>

/* Creating 256 machines with 256 bins each, took 2 1/2 minutes 
   on a fast machine. Secondly, solving this problem in shell 
   was an exercise in tedium. Doing it in C is a million times
   easier, and 10000x faster. 140 seconds vs 6ms */

/* Similarly, spitting this into tc to parse takes 36 seconds
   with 256 machines and 64 bins. I'm cursed by amdahl's law. 
   To what extent this is the parser and to what extent this is
   the kernel is a good question. */

/* It is my hope that with a lot of work, it will be possible 
   to create a qdisc scheme that is reversable so you can then
   look at the statistics sanely with some other tool */

/* Filter handles are decimal for some reason */

#define TC "~d/git/iproute2/tc/tc"
#define IFACE "eth0"
#define BIGQDISC "red min 1500 max 4500 probability 0.02 avpkt 800 limit 16000 burst 5 ecn"

#define OUT stdout

static int MACHINES = 256;
static int BINS = 64; 
static int LIMIT = 12;
static int UPLINK = 4000;
static int MTU = 1500;
static int txqueuelen = 1000;
static int BURST = 1500;
static int DOWNLINK = 1000000;
static int pingopt_top = 0;
static int pingopt_machine = 0;


void usage(int argc, char **argv, char *msg) {
  fprintf(stderr, msg);
  fprintf(stderr,
"-m --machines\n"
"-b --bins\n"
"-t --type\n"
"-u --uplink\n"
"-d --downlink\n"
"-b --burst\n"
"-i --iface\n"
"-p --pingopt\n"
"-M --mtu\n"
"-A --algorithm\n"
"-G --subgroup filter"
"-g --group filter"
"-l --line-rate"

	  );
  exit(-1);
}

enum interface_types {
  ETHERNET_10,
  ETHERNET_100,
  ETHERNET_1000,
  ETHERNET_10000,
  WIRELESS_G,
  WIRELESS_N,
  OTHER,
};

struct interface {
  int speed;
  int mtu;
};

int infer_speed(struct interface *iface) {
}

/* Some design notes: 
  If (linerate) | (uplink == 0 && downlink == 0) {
      we do not need to do cbq or tbf
      }

*/

main() {
  int i,j;
  int multicast, defbin;
  int FILTERS=10;
  int MACHSUBC=MACHINES+3;
  int MACHCLASS=MACHSUBC*4;
  MACHSUBC*=2;
  int BASE=10;

  // Do some setup
  fprintf(stdout,"qdisc del dev %s root\n",IFACE);
  fprintf(stdout,"qdisc add dev %s root handle 1: htb default 20\n",IFACE);

  /* shape everything at UPLINK speed - this prevents huge queues in your
     device which destroy latency */
  
  // BURST=${MTU}b;
  fprintf(OUT,"class add dev %s parent 1: classid 1:1 htb rate %dkbit burst %db\n", IFACE, UPLINK, BURST); 
  fprintf(OUT,"class add dev %s parent 1:1 classid 1:10 htb rate %dkbit burst %db prio 1\n", IFACE, UPLINK, BURST); 
  // bulk & default class 1:20 - gets slightly less traffic, and a lower priority:

  fprintf(OUT,"class add dev %s parent 1:1 classid 1:20 htb rate %dkbit burst %d prio 2\n",
	  IFACE, (UPLINK*94)/100, BURST);
  fprintf(OUT,"class add dev %s parent 1:1 classid 1:30 htb rate %dkbit burst %d prio 3\n",
	  IFACE, (UPLINK*84)/100, BURST);
  fprintf(OUT, "qdisc add dev %s parent 1:10 handle 10: sfq perturb 10\n", IFACE);
  fprintf(OUT, "qdisc add dev %s parent 1:30 handle 30: sfq perturb 10\n", IFACE);

  if(pingopt_top) { 
    fprintf(OUT,"filter add dev %s parent 1:0 protocol ip prio 10 u32 match ip protocol 1 0xff flowid 1:10\n",
	    IFACE);
  }

  /* Go crazy with QFQ */

  fprintf(OUT,"qdisc add dev %s parent 1:20 handle %x qfq\n", IFACE, BASE);
  multicast = MACHINES + 1;
  defbin = MACHINES + 2;

  fprintf(OUT,"class add dev %s parent %x classid %x:%x qfq\n",IFACE,BASE,BASE,multicast);
  fprintf(OUT,"qdisc add dev %s parent %x:%x handle %x %s\n",IFACE,BASE,multicast,multicast,BIGQDISC);
  fprintf(OUT,"class add dev %s parent %x: classid %x:%x qfq\n", IFACE, BASE, BASE, defbin);
  fprintf(OUT,"qdisc add dev %s parent %x:%x handle %x %s\n",IFACE,BASE,defbin,defbin,BIGQDISC);

  // This is a catchall for everything while we setup

  fprintf(OUT,"filter add dev %s protocol all parent %x: prio 999 u32 match ip protocol 0 0x00 flowid %x:%x\n",
	  IFACE, BASE, BASE, defbin);

  fprintf(OUT,"filter add dev %s protocol 802_3 parent %x: prio 4 u32 match u16 0x0100 0x0100 at 0 flowid %x:%x\n",
	  IFACE, BASE, BASE, defbin);
  fprintf(OUT,"filter add dev %s protocol arp parent %x: prio 5 u32 match u16 0x0100 0x0100 at -14 flowid %x:%x\n",
	  IFACE, BASE, BASE, defbin);
  fprintf(OUT,"filter add dev %s protocol ip parent %x: prio 6 u32 match u16 0x0100 0x0100 at -14 flowid %x:%x\n",
	  IFACE, BASE, BASE, defbin);
  fprintf(OUT,"filter add dev %s protocol ipv6 parent %x: prio 7 u32 match u16 0x0100 0x0100 at -14 flowid %x:%x\n",
	  IFACE, BASE, BASE, defbin);

  for(i=0; i<MACHINES;i++) {
    MACHSUBC++;
    MACHCLASS+=i;
    // MACHCLASS??? What happened to that??
    fprintf(OUT,"class add dev %s parent %x: classid %x:%x qfq\n",
	    IFACE,BASE,BASE,i);
    fprintf(OUT,"qdisc add dev %s parent %x:%x handle %x qfq\n",
	    IFACE,BASE,i,MACHSUBC);
    for(j=0; j<BINS; j++) {
      fprintf(OUT,"class add dev %s parent %x: classid %x:%x qfq\n",
	      IFACE, MACHSUBC, MACHSUBC,j);
      fprintf(OUT,"qdisc add dev %s parent %x:%x %s\n",
	      IFACE, MACHSUBC,j,BIGQDISC);
    }
    FILTERS++;
    fprintf(OUT,"filter add dev %s protocol ip parent %x: handle %d prio 97 flow hash keys proto-src,rxhash divisor %d\n", 
	    IFACE, MACHSUBC, FILTERS, BINS);
    FILTERS++;
    fprintf(OUT,"filter add dev %s protocol ipv6 parent %x: handle %d prio 98 flow hash keys proto-src,rxhash divisor %d\n", 
	    IFACE, MACHSUBC, FILTERS, BINS);
    /* ICMP (ip protocol 1) in the default class can do measurements & impress our friends */
    fprintf(OUT,"filter add dev %s parent %x: protocol ip prio 1 u32 match ip protocol 1 0xff flowid %x:%x\n", IFACE, MACHSUBC, MACHSUBC, j);
  }

// And kick everything into action
    FILTERS++;
    // Now, if you are testing from one machine, you really want proto-src
    // But for deployment, you want the pre-nat source

    fprintf(OUT,"filter add dev %s protocol ip parent %x: handle %d prio 97 flow hash keys src divisor %x\n",IFACE,BASE,FILTERS,MACHINES);
    FILTERS++;
    fprintf(OUT,"filter add dev %s protocol ipv6 parent %x: handle %d prio 98 flow hash keys src divisor %x\n",IFACE,BASE,FILTERS,MACHINES);
}
    // Walla!
