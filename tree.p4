#include <core.p4>
#include <v1model.p4>
#include "headers.p4"

#define FRAME_LEN_FIELD 0
#define ETH_TYPE_FIELD 1
#define IP_PROTO_FIELD 2
#define IP_FLAGS_FIELD 3
#define SRC_PORT_FIELD 4
#define DST_PORT_FIELD 5


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

struct metadata_t {
    bit<16> match_node;
    bit<32> match_key;
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
        transition select(hd.ethernet.etherType) {
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
              hdr.ipv4.tos,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
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

    action set_class(bit<8> label){
        if (hdr.ipv4.isValid()) hdr.ipv4.tos = label;
        if (hdr.ipv6.isValid()) hdr.ipv6.trafficClass = label;
        dtFinished = true;
    }

    action to_port_action(bit<9> port){
        standard_metadata.egress_spec = port;
        if (hdr.ipv4.isValid()) hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        if (hdr.ipv6.isValid()) hdr.ipv6.hopLimit = hdr.ipv6.hopLimit - 1;
    }

    action to_next_level(bit<16> nodeId, bit<5>field ){
        meta.match_node=nodeId;

        meta.match_key =    
            (field == SRC_PORT_FIELD ? (bit<32>) hdr.tcp_udp.srcPort : 0) |
            (field == DST_PORT_FIELD ? (bit<32>) hdr.tcp_udp.dstPort : 0) |
            (field == FRAME_LEN_FIELD ? (bit<32>) standard_metadata.packet_length : 0) |
            (field == ETH_TYPE_FIELD ? (bit<32>) hdr.ethernet.etherType : 0) |
            (field == IP_FLAGS_FIELD && hdr.ipv4.isValid() ? (bit<32>) hdr.ipv4.flags : 0) |
            (field == IP_PROTO_FIELD && hdr.ipv4.isValid() ? (bit<32>) hdr.ipv4.protocol : 0) |
            (field == IP_PROTO_FIELD && hdr.ipv6.isValid() ? (bit<32>) hdr.ipv6.nxt : 0);

        log_msg("match_node = {}, field = {}, match_key = {}", {meta.match_node, field, meta.match_key});
    }

    table ipv4_match {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            drop_action;
            to_port_action;
        }
        size = 1024;
        default_action = drop_action;
    }

    table ipv6_match {
        key = {
            hdr.ipv6.dstAddr: lpm;
        }
        actions = {
            drop_action;
            to_port_action;
        }
        size = 1024;
        default_action = drop_action;
    }

    table dt_level0{
	    key = {}
        actions = {
            drop_action;
            set_class;
            to_next_level;
        }
        default_action = drop_action;
    }

    table dt_level1{
	    key = {
            meta.match_node:exact;
            meta.match_key:range;
        }
        actions = {
            drop_action;
            set_class;
            to_next_level;
        }
        size=4;
        default_action = drop_action;
    }

    table dt_level2{
	    key = {
            meta.match_node:exact;
            meta.match_key:range;
        }
        actions = {
            drop_action;
            set_class;
            to_next_level;
        }
        size=16;
        default_action = drop_action;
    }

    table dt_level3{
	    key = {
            meta.match_node:exact;
            meta.match_key:range;
        }
        actions = {
            drop_action;
            set_class;
            to_next_level;
        }
        default_action = drop_action;
    }

    table dt_level4{
	    key = {
            meta.match_node:exact;
            meta.match_key:range;
        }
        actions = {
            drop_action;
            set_class;
            to_next_level;
        }
        default_action = drop_action;
    }

    table dt_level5{
	    key = {
            meta.match_node:exact;
            meta.match_key:range;
        }
        actions = {
            drop_action;
            set_class;
            to_next_level;
        }
        default_action = drop_action;
    }

    apply {
        if (hdr.ipv4.isValid()) ipv4_match.apply();
        if (hdr.ipv6.isValid()) ipv6_match.apply();
        if (dropped) return;
        
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
    apply { 
        hdr.ethernet.dstAddr = 0xFFFFFFFFFFFF;
    }
}

V1Switch(my_parser(),
         my_verify_checksum(),
         my_ingress(),
         my_egress(),
         my_compute_checksum(),
         my_deparser()) main;

