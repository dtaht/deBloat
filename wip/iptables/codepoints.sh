# Codepoint variable reference

# Standard codepoints in decimal

BE=0
AF11=10
AF12=12
AF13=14
AF21=18
AF22=20
AF23=22
AF31=26
AF32=28
AF33=30
AF41=34
AF42=36
AF43=38
EF=46

CS1=8
CS2=16
CS3=24
CS4=32
CS5=40
CS6=48
CS7=56

# Some new (proposed) codepoints

BOFH=4
ANT=42
LB=63
P2P=9

# Some legacy codepoints
# FIXME, do common tos bits and cisco
# FIXME, get CS fixed

KNOWN_CODEPOINTS="0 4 9 10 12 14 18 20 22 26 28 30 34 36 38 42 46 63 8 16 24 32 40 48 56"
UNKNOWN_CODEPOINTS=""

for i in `seq 1 63`
do 
    FOUND=0
    for j in $KNOWN_CODEPOINTS
    do
	if [ "$i" = "$j" ] 
	    then
	    FOUND=1
	fi
    done
    if [ $FOUND = 0 ]
	then
	UNKNOWN_CODEPOINTS="$UNKNOWN_CODEPOINTS $i"
    fi
done

#    This is the relevant table from the RFC
#    |===============+=========+=============+==========================|
#    |Network Control|  CS6    |   110000    | Network routing          |
#    |---------------+---------+-------------+--------------------------|
#    | Telephony     |   EF    |   101110    | IP Telephony bearer      |
#    |---------------+---------+-------------+--------------------------|
#    |  Signaling    |  CS5    |   101000    | IP Telephony signaling   |
#    |---------------+---------+-------------+--------------------------|
#    | Multimedia    |AF41,AF42|100010,100100|   H.323/V2 video         |
#    | Conferencing  |  AF43   |   100110    |  conferencing (adaptive) |
#    |---------------+---------+-------------+--------------------------|
#    |  Real-Time    |  CS4    |   100000    | Video conferencing and   |
#    |  Interactive  |         |             | Interactive gaming       |
#    |---------------+---------+-------------+--------------------------|
#    | Multimedia    |AF31,AF32|011010,011100| Streaming video and      |
#    | Streaming     |  AF33   |   011110    |   audio on demand        |
#    |---------------+---------+-------------+--------------------------|
#    |Broadcast Video|  CS3    |   011000    |Broadcast TV & live events|
#    |---------------+---------+-------------+--------------------------|
#    | Low-Latency   |AF21,AF22|010010,010100|Client/server transactions|
#    |   Data        |  AF23   |   010110    | Web-based ordering       |
#    |---------------+---------+-------------+--------------------------|
#    |     OAM       |  CS2    |   010000    |         OAM&P            |
#    |---------------+---------+-------------+--------------------------|
#    |High-Throughput|AF11,AF12|001010,001100|  Store and forward       |
#    |    Data       |  AF13   |   001110    |     applications         |
#    |---------------+---------+-------------+--------------------------|
#    |    Standard   | DF (CS0)|   000000    | Undifferentiated         |
#    |               |         |             | applications             |
#    |---------------+---------+-------------+--------------------------|
#    | Low-Priority  |  CS1    |   001000    | Any flow that has no BW  |
#    |     Data      |         |             | assurance                |
#     ------------------------------------------------------------------

