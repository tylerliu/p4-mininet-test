//
// Copyright (c) 2019 Noa Zilberman
// All rights reserved.
//
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//


#include <core.p4>
#include <v1model.p4>
#include "headers.p4"

typedef bit<9>  port_t;

// user defined metadata
// used for coding the decision word
//each code is a result of a lookup
struct metadata {
    bit<5> pkt_len_code;
    bit<5> eth_type_code;
    bit<5> ip_proto_code;
    bit<5> srcport_code;
    bit<5> dstport_code;
    bit<7> unused; 
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers_t hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        packet.extract(hdr.ethernet);
        meta.unused = 0;
        transition select(hdr.ethernet.etherType) {
            IPV4_TYPE: parse_ip;
            IPV6_TYPE: parse_ipv6;
            default: accept;
        }
    }

    state parse_ip {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            TCP_TYPE: parse_tcp_udp;
            UDP_TYPE: parse_tcp_udp;
            default: accept;
        }
    }

    state parse_ipv6 {
        packet.extract(hdr.ipv6);
        transition select(hdr.ipv6.nxt) {
            TCP_TYPE: parse_tcp_udp;
            UDP_TYPE: parse_tcp_udp;
            default: accept;
        }
    }

    state parse_tcp_udp {
        packet.extract(hdr.tcp_udp);
        transition accept;
    }
}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers_t hdr, inout metadata meta) {   
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers_t hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    action set_output_port(port_t port) {
        standard_metadata.egress_spec = port;
    }

    
    action set_default_port (){
        standard_metadata.egress_spec = 0x1;
    }

 
    action set_len_code(bit<5> code){
        meta.pkt_len_code = code;
    }
    
    action set_ip_proto_code(bit<5> code){
        meta.ip_proto_code = code;
    }

    action set_eth_type_code(bit<5> code){
        meta.eth_type_code = code;
    }
    
    action set_srcport_code(bit<5> code){
        meta.srcport_code = code;
    }

    action set_dstport_code(bit<5> code){
        meta.dstport_code = code;
    }


//Lookup table - packet length

    table lookup_len {
        key = { standard_metadata.packet_length:ternary; }

        actions = {
            set_len_code;
            NoAction;
        }
        size = 63;
        default_action = NoAction;
    }


//Lookup table - ip protocol

    table lookup_ip_proto {
        key = { hdr.ipv4.protocol :ternary; }

        actions = {
            set_ip_proto_code;
            NoAction;
        }
        size = 63;
        default_action = NoAction;
    }

//Lookup table - ethernet type
    table lookup_eth_type {
        key = { hdr.ethernet.etherType:ternary; }

        actions = {
            set_eth_type_code;
            NoAction;
        }
        size = 63;
        default_action = NoAction;
    }


//Lookup table - TCP source port
     table lookup_srcport {
        key = { hdr.tcp_udp.srcPort:ternary; }

        actions = {
            set_srcport_code;
            NoAction;
        }
        size = 63;
        default_action = NoAction;
    }

//Lookup table - TCP dest port
     table lookup_dstport {
        key = { hdr.tcp_udp.dstPort:ternary; }

        actions = {
            set_dstport_code;
	    NoAction;
        }
        size = 63;
        default_action = NoAction;
    }

//Decision table - lookup code
     table lookup_code {
        key = { meta.pkt_len_code++meta.eth_type_code++meta.ip_proto_code++meta.srcport_code++meta.dstport_code:exact @name("code"); }

        actions = {
            set_output_port;
            set_default_port;
        }
        size = 64;
        default_action = set_default_port;
    }




    apply {

        meta.pkt_len_code=0;
        meta.ip_proto_code=0;
        meta.eth_type_code=0;
        meta.srcport_code=0;
        meta.dstport_code=0;
       
        lookup_len.apply();
        
        if (hdr.ethernet.isValid()) {
            lookup_eth_type.apply();
        }

        if (hdr.ipv4.isValid()) {
            lookup_ip_proto.apply();
        }

        if (hdr.tcp_udp.isValid()){
            lookup_srcport.apply();
            lookup_dstport.apply();
        }
  
        if (!lookup_code.apply().hit) {
            mark_to_drop(standard_metadata);
        }
      }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers_t hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers_t  hdr, inout metadata meta) {
     apply {
        update_checksum(
            hdr.ipv4.isValid(),
                { 
                    hdr.ipv4.version,
                    hdr.ipv4.ihl,
                    hdr.ipv4.tos,
                    hdr.ipv4.totalLen,
                    hdr.ipv4.identification,
                    hdr.ipv4.flags,
                    hdr.ipv4.fragOffset,
                    hdr.ipv4.ttl,
                    hdr.ipv4.protocol,
                    hdr.ipv4.srcAddr,
                    hdr.ipv4.dstAddr 
                },
                hdr.ipv4.hdrChecksum,
                HashAlgorithm.csum16);
        }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers_t hdr) {
    apply {
        packet.emit(hdr.ethernet); 
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6);
	    packet.emit(hdr.tcp_udp);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
