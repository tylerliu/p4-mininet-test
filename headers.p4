
#define IPV4_TYPE 0x0800
#define IPV6_TYPE 0x86DD
#define TCP_TYPE 6
#define UDP_TYPE 17

typedef bit<48> EthernetAddress;
typedef bit<32> IPv4Address;
typedef bit<128> IPv6Address;

//Standard Ethernet Header
header ethernet_t {
    EthernetAddress dstAddr;
    EthernetAddress srcAddr;
    bit<16> etherType;
}

//ip header without options
header ipv4_t {
    bit<4> version;
    bit<4> ihl;
    bit<8> tos;
    bit<16> totalLen;
    bit<16> identification;
    bit<3> flags;
    bit<13> fragOffset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdrChecksum;
    IPv4Address srcAddr;
    IPv4Address dstAddr;
}


//IPv6 header
header ipv6_t{
  bit<4> version;
  bit<8> trafficClass;
  bit<20> flowLabel;
  bit<16> payloadLen;
  bit<8> nxt;
  bit<8> hopLimit;
  IPv6Address srcAddr;
  IPv6Address dstAddr;
}

header TCP_UDP_t {
    bit<16> srcPort;
    bit<16> dstPort;
}

struct headers_t {
    ethernet_t ethernet;
    ipv4_t     ipv4;
    ipv6_t     ipv6;
    TCP_UDP_t tcp_udp;
}