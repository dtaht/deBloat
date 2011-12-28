#summary packet generator for wireshark dissector example
{{{
-- packet-gen.lua - packet generator for wireshark dissector example

require "bitstring"
require "socket"

local packet_with_length = bitstring.fromhexstream("027d00452b810000003b1403010001011603010030e832a38bead627240577b715945a7c1df64ea6ab24b0f51fce7768249bd2f6fe95c9e2c2c80af5d467e2262ed4df06f5")

local packet_no_lenght = bitstring.fromhexstream("01fd004b2b0117030100408665ba353d9b1fd1d6f179898951e8bc90206d43cf7342b0b63f552e90b3a6e068ceb3905d365cff160387a264a1cd8062d5ee1cc819deb2c0754e557683b3a1")

-- there is no need to send to a real address
-- these two packets will be captured by Wireshark
sock = socket.udp()
sock:sendto(packet_with_length, "1.1.1.1", 1818)
sock:sendto(packet_no_lenght, "1.1.1.1", 1818)
}}}
