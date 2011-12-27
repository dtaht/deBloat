#! /usr/bin/perl -w

#######################
# tcparsestat.pl
# --------------
# read class statistics from tc command line
# convert them from bytes to bits
# store them into a RRD database
# --------------
# j. vehent - 04/2010
#######################
 
use strict;
use RRDs;
 
use Proc::Daemon;
Proc::Daemon::Init;
 
my $rrdfile = "/var/www/tcgraph/tcgraph.rrd";
my $logfile = "/var/www/tcgraph/tcgraph.log";
my $updatefreq = 60;
 
while(1)
{
        # define list of classes to check with default value = 'U'
        # ('U' means unknown in RRD tool langage)
        my %classlist=(
           10 => 'U',
           20 => 'U',
           30 => 'U',
           40 => 'U',
           50 => 'U',
           60 => 'U',
           99 => 'U'
           );
 
        my %valuelist = %classlist;
 
        # get statistics from command line
        open(TCSTAT,"tc -s class show dev eth0 |") || die "could not open tc command line";
                
        # look for specified classes into command line result
        while(<TCSTAT>)
        {
           chomp $_;
           # do we have class information in this line ?
           foreach my $class (keys %classlist)
           {
              if ($_ =~ /\:$class parent/)
              {
                 # If yes, go to the next line and get the Sent value
                 my $nextline = <TCSTAT>;
 
                 my @splitline = split(/ /,$nextline);
 
                 # multiplicate by 8 to store bits and not bytes, and store it
                 $valuelist{$class} = $splitline[2]*8;
 
                 # do not check this specific class for this time
                 delete $classlist{$class};
              }
           }
        }
 
        my $thissecond = time();
 
        # update line is :
        # <unix time>:<statistic #1>:...:<statistic #n>
        my $updateline = time().":$valuelist{'10'}:$valuelist{'20'}:$valuelist{'30'}:$valuelist{'40'}:$valuelist{'50'}:$valuelist{'60'}:$valuelist{'99'}";
        RRDs::update $rrdfile, "$updateline";
 
        if (defined $logfile)
        {
           open(TCGLOG,">>$logfile");
           print TCGLOG "$updateline\n";
           close TCGLOG;
        }
 
        close TCSTAT;
 
        # sleep until next period
        sleep $updatefreq;
}
