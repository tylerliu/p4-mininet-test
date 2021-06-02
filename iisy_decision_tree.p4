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


typedef bit<48> EthAddr_t; 
typedef bit<32> ipAddr_t;
typedef bit<16> TCPAddr_t;
typedef bit<9>  port_t;

#define ip_TYPE 0x0800
#define IPV6_TYPE 0x86DD
#define TCP_TYPE 6

//Standard Ethernet Header
header Ethernet_h {
    EthAddr_t dstAddr;
    EthAddr_t srcAddr;
    bit<16> etherType;
}

//ip header without options
header ip_h {
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
    ipAddr_t srcAddr;
    ipAddr_t dstAddr;
}

//IPv6 header
header IPv6_h{
  bit<4> version;
  bit<8> trafficClass;
  bit<20> flowLabel;
  bit<16> payloadLen;
  bit<8> nxt;
  bit<8> hopLimit;
  bit<128> srcAddr;
  bit<128> dstAddr;
}

//TCP header without options
header TCP_h {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4> dataOffset;
    bit<4> res;
    bit<8> flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}


// List of all recognized headers
struct headers {
    Ethernet_h ethernet;
    ip_h ip;
    IPv6_h ip6;
    TCP_h tcp;
}


// user defined metadata
// used for coding the decision word
//each code is a result of a lookup
struct metadata {
    bit<5> pkt_len_code;
    bit<5> ip_proto_code;
    bit<5> ip_flags_code;
    bit<5> tcp_srcport_code;
    bit<5> tcp_dstport_code;
    bit<7> unused; 
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        packet.extract(hdr.ethernet);
        meta.unused = 0;
        transition select(hdr.ethernet.etherType) {
            ip_TYPE: parse_ip;
            IPV6_TYPE: parse_ipv6;
            default: accept;
        }
    }

    state parse_ip {
        packet.extract(hdr.ip);
        transition select(hdr.ip.protocol) {
            TCP_TYPE: parse_tcp;
            default: accept;
        }
    }

    state parse_ipv6 {
        packet.extract(hdr.ip6);
        transition select(hdr.ip6.nxt) {
            TCP_TYPE: parse_tcp;
            default: accept;
        }
    }

    state parse_tcp {
        packet.extract(hdr.tcp);
        transition accept;
    }
}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
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

    action set_ip_flags_code(bit<5> code){
        meta.ip_flags_code = code;
    }
    
    action set_tcp_srcport_code(bit<5> code){
        meta.tcp_srcport_code = code;
    }

    action set_tcp_dstport_code(bit<5> code){
        meta.tcp_dstport_code = code;
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
        key = { hdr.ip.protocol:ternary; }

        actions = {
            set_ip_proto_code;
            NoAction;
        }
        size = 63;
        default_action = NoAction;
    }

//Lookup table - ip flags
    table lookup_ip_flags {
        key = { hdr.ip.flags:ternary; }

        actions = {
            set_ip_flags_code;
            NoAction;
        }
        size = 63;
        default_action = NoAction;
    }


//Lookup table - TCP source port
     table lookup_tcp_srcport {
        key = { hdr.tcp.srcPort:ternary; }

        actions = {
            set_tcp_srcport_code;
            NoAction;
        }
        size = 63;
        default_action = NoAction;
    }

//Lookup table - TCP dest port
     table lookup_tcp_dstport {
        key = { hdr.tcp.dstPort:ternary; }

        actions = {
            set_tcp_dstport_code;
	    NoAction;
        }
        size = 63;
        default_action = NoAction;
    }

//Decision table - lookup code
     table lookup_code {
        key = { meta.pkt_len_code++meta.ip_proto_code++meta.ip_flags_code++meta.tcp_srcport_code++meta.tcp_dstport_code:exact @name("code"); }

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
        meta.ip_flags_code=0;
        meta.tcp_srcport_code=0;
        meta.tcp_dstport_code=0;
       
        lookup_len.apply();
        

        if (hdr.ip.isValid()) {

            lookup_ip_proto.apply();
            lookup_ip_flags.apply();
        }

        if (hdr.tcp.isValid()){
            lookup_tcp_srcport.apply();
            lookup_tcp_dstport.apply();
        }
  
        if (!lookup_code.apply().hit) {
            mark_to_drop(standard_metadata);
        }
      }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
     apply {
        update_checksum(
            hdr.ip.isValid(),
                { 
                    hdr.ip.version,
                    hdr.ip.ihl,
                    hdr.ip.tos,
                    hdr.ip.totalLen,
                    hdr.ip.identification,
                    hdr.ip.flags,
                    hdr.ip.fragOffset,
                    hdr.ip.ttl,
                    hdr.ip.protocol,
                    hdr.ip.srcAddr,
                    hdr.ip.dstAddr 
                },
                hdr.ip.hdrChecksum,
                HashAlgorithm.csum16);
        }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet); 
        packet.emit(hdr.ip);
        packet.emit(hdr.ip6);
	    packet.emit(hdr.tcp);
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
