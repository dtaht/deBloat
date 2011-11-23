tc filter add dev $IFACE protocol 802_3 parent 1: \
	u32 match u32 bla bla at 0
	u32 match u16 bla bla at 4 flowid 1:11


# ip specific

tc filter add dev $IFACE protocol ip parent 1: \
	u32 match u32 0xabcdefghah 0xffffffff at -12 \
	u32 match u16 0x1234 at -14 flowid 1:40
