#include <core.p4>
#include <v1model.p4>

#define UDP_TYPE 17

#define SRC_ADDR_FIELD 0
#define DST_ADDR_FIELD 1
#define SRC_PORT_FIELD 2
#define DST_PORT_FIELD 3

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

header ethernet_t {
    EthernetAddress dst_addr;
    EthernetAddress src_addr;
    bit<16>         ether_type;
}

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

header UDP_t {
    bit<16> srcPort;
    bit<16> dstPort;
    //bit<16> len;
    //bit<16> checksum;
}

struct headers_t {
    ethernet_t ethernet;
    ipv4_t     ipv4;
    UDP_t udp;
}

struct metadata_t {
    bit<48> match_key;
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
            0x0800:  parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hd.ipv4);
        verify(hd.ipv4.version == 4w4, error.IPv4IncorrectVersion);
        verify(hd.ipv4.ihl == 4w5, error.IPv4OptionsNotSupported);
        transition select(hd.ipv4.protocol){
            UDP_TYPE: parse_udp;
            default: accept;
        }
    }    

    state parse_udp{
        packet.extract(hd.udp);
        transition accept;
    }
}

control my_deparser(packet_out packet,
                   in headers_t hdr)
{
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.udp);
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
    apply { }
}

control my_ingress(inout headers_t hdr,
                  inout metadata_t meta,
                  inout standard_metadata_t standard_metadata)
{
    bool dropped = false;
    bool dtFinished = false;
    action noop(){
//        standard_metadata.egress_spec=standard_metadata.egress_spec-1;
    }

    action breakDT(){
        dtFinished = true;
    }

    action drop_action() {
        mark_to_drop(standard_metadata);
        dropped = true;
        dtFinished = true;
    }

    action to_port_action_dt(bit<9> port){
        standard_metadata.egress_spec = port;
        dtFinished = true;
    }

    action to_next_level(bit<16> nodeId, bit<5>field ){
        meta.match_key[31:0]=0;
        meta.match_key[47:32]=nodeId;
        if (field == SRC_ADDR_FIELD) {
            meta.match_key[31:0]=hdr.ipv4.src_addr;
        } else if (field == DST_ADDR_FIELD) {
            meta.match_key[31:0]=hdr.ipv4.dst_addr;
        } else if (field == SRC_PORT_FIELD) {
            meta.match_key[15:0]=hdr.udp.srcPort;
        } else if (field == DST_PORT_FIELD) {
            meta.match_key[15:0]=hdr.udp.dstPort;
        }
        log_msg("sport = {}, dport = {},src={}", {hdr.udp.srcPort, hdr.udp.dstPort,hdr.ipv4.src_addr});
    }

    table dt_level0{
	    key = {
            meta.match_key:ternary;
        }
        actions = {
            drop_action;
            to_port_action_dt;
            to_next_level;
            noop;
            breakDT;
        }
        size=16;
        default_action = to_next_level(1,DST_PORT_FIELD);
    }

    table dt_level1{
	    key = {
            meta.match_key:exact;
        }
        actions = {
            drop_action;
            to_port_action_dt;
            to_next_level;
            noop;
            breakDT;
        }
        //size=16;
        default_action = breakDT;
        const entries = {
            0x00010000ffff:to_next_level(5,SRC_PORT_FIELD);//will transit to node 5. Match src port
        }
    }

    table dt_level2{
	    key = {
            meta.match_key:exact;
        }
        actions = {
            drop_action;
            to_port_action_dt;
            to_next_level;
            noop;
            breakDT;
        }
        //size=16;
        default_action = breakDT;
        const entries = {
            0x0005000000ff:drop_action();
        }
    }

    action to_port_action(bit<9> port) {
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
        standard_metadata.egress_spec = port;
    }

    table ipv4_match {
        key = {
            hdr.ipv4.dst_addr: lpm;
        }
        actions = {
            drop_action;
            to_port_action;
        }
        size = 1024;
        default_action = drop_action;
    }

    apply {
        ipv4_match.apply();
        if (dropped) return;
        dt_level0.apply();
        if (dtFinished) return;
        //log_msg("sport = {}, dport = {}", {hdr.udp.srcPort, hdr.udp.dstPort});
        dt_level1.apply();
        if (dtFinished) return;
        dt_level2.apply();
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

