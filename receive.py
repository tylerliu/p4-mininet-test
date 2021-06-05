#!/usr/bin/env python
import sys
import struct
import os

from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr
from scapy.all import Packet, IPOption
from scapy.all import ShortField, IntField, LongField, BitField, FieldListField, FieldLenField
from scapy.all import Ether, IP, TCP, UDP, Raw, IPv6, IPv6ExtHdrHopByHop
from scapy.layers.inet import _IPOption_HDR
from myTunnel_header import MyTunnel

def get_if():
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break;
    if not iface:
        print "Cannot find eth0 interface"
        exit(1)
    return iface

def handle_pkt(pkt):
    # if MyTunnel in pkt or (TCP in pkt and pkt[TCP].dport == 1234):
    print "got a packet"
    # pkt.show2()
    print("validate information:")
    print("frame_len: " + str(pkt.len))
    print("eth_type: " + str(hex(pkt[Ether].type)))
    print("ip_proto: " + str(pkt[IP].proto))
    # TODO
    print("ip_flags(failed to set, need debug): " + str(hex(pkt[IP].flags)))
    if IPv6 in pkt:
        print("ipv6_nxt: " + str(pkt[IPv6].nh))
    if IPv6ExtHdrHopByHop in pkt:
        print("ipv6_opt: " + str(pkt[IPv6ExtHdrHopByHop].options))
    if TCP in pkt:
        print("tcp_srcport: " + str(pkt[TCP].sport))
        print("tcp_dstport: " + str(pkt[TCP].dport))
        print("tcp_flags: " + str(hex(pkt[TCP].flags)))
    if UDP in pkt:
        print("udp_srcport: " + str(pkt[UDP].sport))
        print("udp_dstport: " + str(pkt[UDP].dport))
#        hexdump(pkt)
#        print "len(pkt) = ", len(pkt)
    sys.stdout.flush()


def main():
    ifaces = filter(lambda i: 'eth' in i, os.listdir('/sys/class/net/'))
    iface = ifaces[0]
    print "sniffing on %s" % iface
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x))

if __name__ == '__main__':
    main()
