#include <core.p4>
#include <v1model.p4>

#define IPV4_TYPE 0x0800
#define IPV6_TYPE 0x86DD
#define TCP_TYPE 6
#define UDP_TYPE 17

#define SRC_ADDR_FIELD 0
#define DST_ADDR_FIELD 1
#define SRC_PORT_FIELD 2
#define DST_PORT_FIELD 3
#define FRAME_LEN_FIELD 4
#define ETH_TYPE_FIELD 5
#define IP_PROTO_FIELD 6

/*
decision tree table entry example

 udp src port in [3...5] -> node7 in next level, node *7* will match on *port*

To match on entry in each level, the data will have a prefix that is the "tree node id" in that level.
                A
               / \
              B   C
A will be the root node, B is node 0 in level 1. C is node 1 in level 1. B and C may match on different features. 
There are two entries at level0: one goes to B and one goes to C. Here, the entry for B will trigger an action that extract the feature B wants.
*/
typedef bit<48> EthernetAddress;
typedef bit<32> IPv4Address;
typedef bit<128> IPv6Address;

header ethernet_t {
    EthernetAddress dst_addr;
    EthernetAddress src_addr;
    bit<16>         ether_type;
}

//IPv6 header
header ipv4_t {
    bit<4>      version;
    bit<4>      ihl;
    bit<8>      diffserv;
    bit<16>     total_len;
    bit<16>     identification;
    bit<3>      flags;
    bit<13>     frag_offset;
    bit<8>      ttl;
    bit<8>      protocol;
    bit<16>     hdr_checksum;
    IPv4Address src_addr;
    IPv4Address dst_addr;
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

struct metadata_t {
    bit<16> match_node;
    bit<32> match_key1;
    bit<32> match_key2;
}

error {
    IPv4IncorrectVersion,
    IPv4OptionsNotSupported
}

parser my_parser(packet_in packet,
                out headers_t hd,
                inout metadata_t meta,
                inout standard_metadata_t standard_meta)
{
    state start {
        packet.extract(hd.ethernet);
        transition select(hd.ethernet.ether_type) {
            IPV4_TYPE:  parse_ipv4;
            IPV6_TYPE:  parse_ipv6;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hd.ipv4);
        transition select(hd.ipv4.protocol){
            TCP_TYPE: parse_tcp_udp;
            UDP_TYPE: parse_tcp_udp;
            default: accept;
        }
    }    

    state parse_ipv6 {
        packet.extract(hd.ipv6);
        transition select(hd.ipv6.nxt){
            TCP_TYPE: parse_tcp_udp;
            UDP_TYPE: parse_tcp_udp;
            default: accept;
        }
    }   

    state parse_tcp_udp{
        packet.extract(hd.tcp_udp);
        transition accept;
    }
}

control my_deparser(packet_out packet,
                   in headers_t hdr)
{
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6);
        packet.emit(hdr.tcp_udp);
    }
}

control my_verify_checksum(inout headers_t hdr,
                         inout metadata_t meta)
{
    apply { }
}

control my_compute_checksum(inout headers_t hdr,
                          inout metadata_t meta)
{
    apply { 
        update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	          hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.total_len,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.frag_offset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.src_addr,
              hdr.ipv4.dst_addr },
            hdr.ipv4.hdr_checksum,
            HashAlgorithm.csum16);
    }
}

control my_ingress(inout headers_t hdr,
                  inout metadata_t meta,
                  inout standard_metadata_t standard_metadata)
{
    bool dropped = false;
    bool dtFinished = false;

    action drop_action() {
        mark_to_drop(standard_metadata);
        dropped = true;
        dtFinished = true;
    }

    action to_port_action(bit<9> port){
        standard_metadata.egress_spec = port;
        dtFinished = true;
    }

    action to_next_level(bit<16> nodeId, bit<5>field1, bit<5>field2){
        meta.match_node=nodeId;

        meta.match_key1 =    
            (field1 == SRC_ADDR_FIELD && hdr.ipv4.isValid() ? (bit<32>) hdr.ipv4.src_addr : 0) |
            (field1 == SRC_ADDR_FIELD && hdr.ipv6.isValid() ? (bit<32>) hdr.ipv6.srcAddr : 0)  |
            (field1 == DST_ADDR_FIELD && hdr.ipv4.isValid() ? (bit<32>) hdr.ipv4.dst_addr : 0) |
            (field1 == DST_ADDR_FIELD && hdr.ipv6.isValid() ? (bit<32>) hdr.ipv6.dstAddr : 0)  |
            (field1 == SRC_PORT_FIELD ? (bit<32>) hdr.tcp_udp.srcPort : 0) |
            (field1 == DST_PORT_FIELD ? (bit<32>) hdr.tcp_udp.dstPort : 0) |
            (field1 == FRAME_LEN_FIELD ? (bit<32>) standard_metadata.packet_length : 0) |
            (field1 == ETH_TYPE_FIELD ? (bit<32>) hdr.ethernet.ether_type : 0) |
            (field1 == IP_PROTO_FIELD && hdr.ipv4.isValid() ? (bit<32>) hdr.ipv4.protocol : 0) |
            (field1 == IP_PROTO_FIELD && hdr.ipv6.isValid() ? (bit<32>) hdr.ipv6.nxt : 0);
        
        meta.match_key2 =    
            (field2 == SRC_ADDR_FIELD && hdr.ipv4.isValid() ? (bit<32>) hdr.ipv4.src_addr : 0) |
            (field2 == SRC_ADDR_FIELD && hdr.ipv6.isValid() ? (bit<32>) hdr.ipv6.srcAddr : 0)  |
            (field2 == DST_ADDR_FIELD && hdr.ipv4.isValid() ? (bit<32>) hdr.ipv4.dst_addr : 0) |
            (field2 == DST_ADDR_FIELD && hdr.ipv6.isValid() ? (bit<32>) hdr.ipv6.dstAddr : 0)  |
            (field2 == SRC_PORT_FIELD ? (bit<32>) hdr.tcp_udp.srcPort : 0) |
            (field2 == DST_PORT_FIELD ? (bit<32>) hdr.tcp_udp.dstPort : 0) |
            (field2 == FRAME_LEN_FIELD ? (bit<32>) standard_metadata.packet_length : 0) |
            (field2 == ETH_TYPE_FIELD ? (bit<32>) hdr.ethernet.ether_type : 0) |
            (field2 == IP_PROTO_FIELD && hdr.ipv4.isValid() ? (bit<32>) hdr.ipv4.protocol : 0) |
            (field2 == IP_PROTO_FIELD && hdr.ipv6.isValid() ? (bit<32>) hdr.ipv6.nxt : 0);

        log_msg("match_node = {}, field1 = {}, match_key1 = {}, field2 = {}, match_key2 = {}", 
                {meta.match_node, field1, meta.match_key1, field2, meta.match_key2});
    }

    table dt_level0{
	    key = {}
        actions = {
            drop_action;
            to_port_action;
            to_next_level;
        }
        default_action = drop_action;
    }

    table dt_level1{
	    key = {
            meta.match_node:exact;
            meta.match_key1:range;
            meta.match_key2:range;
        }
        actions = {
            drop_action;
            to_port_action;
            to_next_level;
        }
        size=16;
        default_action = drop_action;
    }

    table dt_level2{
	    key = {
            meta.match_node:exact;
            meta.match_key1:range;
            meta.match_key2:range;
        }
        actions = {
            drop_action;
            to_port_action;
            to_next_level;
        }
        default_action = drop_action;
    }

    table dt_level3{
	    key = {
            meta.match_node:exact;
            meta.match_key1:range;
            meta.match_key2:range;
        }
        actions = {
            drop_action;
            to_port_action;
            to_next_level;
        }
        default_action = drop_action;
    }

    table dt_level4{
	    key = {
            meta.match_node:exact;
            meta.match_key1:range;
            meta.match_key2:range;
        }
        actions = {
            drop_action;
            to_port_action;
            to_next_level;
        }
        default_action = drop_action;
    }

    table dt_level5{
	    key = {
            meta.match_node:exact;
            meta.match_key1:range;
            meta.match_key2:range;
        }
        actions = {
            drop_action;
            to_port_action;
            to_next_level;
        }
        default_action = drop_action;
    }

    apply {
        if (hdr.ipv4.isValid()) hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        if (hdr.ipv6.isValid()) hdr.ipv6.hopLimit = hdr.ipv6.hopLimit - 1;
        dt_level0.apply();
        if (dtFinished) return;
        dt_level1.apply();
        if (dtFinished) return;
        dt_level2.apply();
        if (dtFinished) return;
        dt_level3.apply();
        if (dtFinished) return;
        dt_level4.apply();
        if (dtFinished) return;
        dt_level5.apply();
    }
}

control my_egress(inout headers_t hdr,
                 inout metadata_t meta,
                 inout standard_metadata_t standard_metadata)
{
    apply { }
}

V1Switch(my_parser(),
         my_verify_checksum(),
         my_ingress(),
         my_egress(),
         my_compute_checksum(),
         my_deparser()) main;

