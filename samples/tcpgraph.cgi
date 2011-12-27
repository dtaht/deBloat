#!/usr/bin/perl -w
 
# tcgraph -- traffic control graphing tool
# Julien Vehent - 04/2010
# inspired from Mailgraph: David Schweikert <david@schweikert.ch> 
# released under the GNU General Public License
 
use RRDs; 
use POSIX qw(uname);
 
my $VERSION = "20100415";
 
my $host = (POSIX::uname())[1]; 
my $scriptname = 'tcgraph.cgi'; 
my $xpoints = 500;
my $points_per_sample = 3; 
my $ypoints = 110;
my $ypoints_err = 50; 
my $rrd = '/var/www/tcgraph/tcgraph.rrd';      # path to where the RRD database is 
my $tmp_dir = '/tmp/tcgraph'; # temporary directory where to store the images 
 
my @graphs = ( 
   { title => 'Last Hours', seconds => 3600*4,   },
   { title => 'Last Day',   seconds => 3600*24,   }, 
   { title => 'Last Week',  seconds => 3600*24*7, }, 
   { title => 'Last Month', seconds => 3600*24*31,     }, 
   { title => 'Last Year',  seconds => 3600*24*365, },
); 
 
sub rrd_graph(@) 
{
   my ($range, $file, $ypoints, @rrdargs) = @_; 
   my $step = $range*$points_per_sample/$xpoints;
   # choose carefully the end otherwise rrd will maybe pick the wrong RRA: 
   my $end  = time; $end -= $end % $step;
   my $date = localtime(time);
   $date =~ s|:|\\:|g unless $RRDs::VERSION < 1.199908; 
 
   my ($graphret,$xs,$ys) = RRDs::graph($file,
      '--imgformat', 'PNG',
      '--width', $xpoints, 
      '--height', $ypoints,
      '--start', "-$range",
      '--end', $end,
      '--vertical-label', 'bits/s', 
      '--lower-limit', 0,
      #'--units-exponent', 0, # don't show milli-messages/s 
      '--color', 'BACK#333333', 
      '--color', 'SHADEA#000000', 
      '--color', 'SHADEB#000000', 
      '--color', 'CANVAS#000000', 
      '--color', 'GRID#999999', 
      '--color', 'MGRID#666666',
      '--color', 'FONT#CCCCCC', 
      '--color', 'FRAME#333333',
      #'--textalign', 'left',
      #'--lazy', 
      $RRDs::VERSION < 1.2002 ? () : ( '--slope-mode'), 
 
      @rrdargs,
 
      'COMMENT:['.$date.']\r', 
   );
 
   my $ERR=RRDs::error; 
   die "ERROR: $ERR\n" if $ERR; 
}
 
sub graph($$)
{
   my ($range, $file) = @_;
   my $step = $range*$points_per_sample/$xpoints;
   rrd_graph($range, $file, $ypoints,
      "DEF:interactive=$rrd:interactive:AVERAGE",
      'AREA:interactive#ffe400:interactive:STACK', 
      'GPRINT:interactive:MAX:\tmax = %6.2lf%Sbps', 
      'GPRINT:interactive:LAST:\tlast = %6.2lf%Sbps',
      'GPRINT:interactive:AVERAGE:\tavg = %6.2lf%Sbps\n',

      "DEF:tcp_acks=$rrd:tcp_acks:AVERAGE",
      'AREA:tcp_acks#b535ff:tcp_acks:STACK', 
      'GPRINT:tcp_acks:MAX:\tmax = %6.2lf%Sbps', 
      'GPRINT:tcp_acks:LAST:\tlast = %6.2lf%Sbps',
      'GPRINT:tcp_acks:AVERAGE:\tavg = %6.2lf%Sbps\n', 
       
      "DEF:ssh=$rrd:ssh:AVERAGE", 
      'AREA:ssh#1b7b16:ssh:STACK',
      'GPRINT:ssh:MAX:\t\tmax = %6.2lf%Sbps', 
      'GPRINT:ssh:LAST:\tlast = %6.2lf%Sbps', 
      'GPRINT:ssh:AVERAGE:\tavg = %6.2lf%Sbps\n',
 
      "DEF:http_s=$rrd:http_s:AVERAGE", 
      'AREA:http_s#ff0000:http_s:STACK',
      'GPRINT:http_s:MAX:\tmax = %6.2lf%Sbps',
      'GPRINT:http_s:LAST:\tlast = %6.2lf%Sbps',
      'GPRINT:http_s:AVERAGE:\tavg = %6.2lf%Sbps\n', 
 
      "DEF:file_xfer=$rrd:file_xfer:AVERAGE", 
      'AREA:file_xfer#00CC33:file_xfer:STACK',
      'GPRINT:file_xfer:MAX:\tmax = %6.2lf%Sbps', 
      'GPRINT:file_xfer:LAST:\tlast = %6.2lf%Sbps', 
      'GPRINT:file_xfer:AVERAGE:\tavg = %6.2lf%Sbps\n',
 
      "DEF:downloads=$rrd:downloads:AVERAGE",
      'AREA:downloads#7316f2:downloads:STACK', 
      'GPRINT:downloads:MAX:\tmax = %6.2lf%Sbps',
      'GPRINT:downloads:LAST:\tlast = %6.2lf%Sbps',
      'GPRINT:downloads:AVERAGE:\tavg = %6.2lf%Sbps\n',
 
      "DEF:default=$rrd:default:AVERAGE",
      'AREA:default#bcdd94:default:STACK', 
      'GPRINT:default:MAX:\tmax = %6.2lf%Sbps',
      'GPRINT:default:LAST:\tlast = %6.2lf%Sbps',
      'GPRINT:default:AVERAGE:\tavg = %6.2lf%Sbps\n' 
 
   );
}
 
 
sub print_html() 
{
   print "Content-Type: text/html\n\n";
 
   print <<HEADER;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" /> 
<title>Traffic Control statistics for $host</title>
<meta http-equiv="Refresh" content="300" /> 
<meta http-equiv="Pragma" content="no-cache" />
<link rel="stylesheet" href="tcgraph.css" type="text/css" /> 
</head> 
<body>
HEADER
 
   print "<h1>Traffic Control statistics for $host</h1>\n"; 
 
   print "<ul id=\"jump\">\n";
   for my $n (0..$#graphs) { 
      print "  <li><a href=\"#G$n\">$graphs[$n]{title}</a>&nbsp;</li>\n";
   } 
   print "</ul>\n"; 
 
   for my $n (0..$#graphs) { 
      print "<h2 id=\"G$n\">$graphs[$n]{title}</h2>\n"; 
      print "<p><img src=\"$scriptname?${n}-n\" alt=\"tcgraph\"/></p>\n";
   } 
 
   print <<FOOTER;
<hr/> 
<table><tr><td>
<a href="http://wiki.linuxwall.info/doku.php/en:ressources:dossiers:networking:tcgraph">TCgraph</a> v.$VERSION
by <a href="http://jve.linuxwall.info">Julien Vehent</a></td>
<td align="right">
<a href="http://oss.oetiker.ch/rrdtool/"><img src="http://oss.oetiker.ch/rrdtool/.pics/rrdtool.gif" alt="" width="60
" height="17"/></a> 
and <a href="http://david.schweikert.ch/">Mailgraph</a></td> 
</td></tr></table>
</body></html> 
FOOTER
}
 
sub send_image($)
{
   my ($file)= @_;
 
   -r $file or do {
      print "Content-type: text/plain\n\nERROR: can't find $file\n";
      exit 1;
   };
 
   print "Content-type: image/png\n";
   print "Content-length: ".((stat($file))[7])."\n";
   print "\n";
   open(IMG, $file) or die;
   my $data;
   print $data while read(IMG, $data, 16384)>0;
}
 
sub main()
{
   my $uri = $ENV{REQUEST_URI} || '';
   $uri =~ s/\/[^\/]+$//;
   $uri =~ s/\//,/g;
   $uri =~ s/(\~|\%7E)/tilde,/g;
   mkdir $tmp_dir, 0777 unless -d $tmp_dir;
   mkdir "$tmp_dir/$uri", 0777 unless -d "$tmp_dir/$uri";
 
   my $img = $ENV{QUERY_STRING};
   if(defined $img and $img =~ /\S/) {
      if($img =~ /^(\d+)-n$/) {
    my $file = "$tmp_dir/$uri/tcgraph_$1.png";
    graph($graphs[$1]{seconds}, $file);
    send_image($file);
      }
      else {
    die "ERROR: invalid argument\n";
      }
   }
   else {
      print_html;
   }
}
 
main;
