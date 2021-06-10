#!/usr/bin/env python
import argparse
import sys
import socket
import random
import struct
from csv import reader
from scapy.all import sendp, send, get_if_list, get_if_hwaddr
from scapy.all import Packet
from scapy.all import Ether, IP, UDP, TCP, IPv6, IPv6ExtHdrHopByHop, Jumbo

def get_if():
    ifs=get_if_list()
    iface=None # "h1-eth0"
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break;
    if not iface:
        print "Cannot find eth0 interface"
        exit(1)
    return iface

def main():
    if len(sys.argv) < 3:
        print 'pass 2 arguments: <destination> <csv_file_path>'
        exit(1)

    addr = socket.gethostbyname(sys.argv[1])
    iface = get_if()
    print "sending on interface %s to %s" % (iface, str(addr))

    with open(sys.argv[2], 'r') as read_obj:
        csv_reader = reader(read_obj)
        for i,row in enumerate(csv_reader):
            frame_len = int(row[0])
            eth_type = int(row[1], 16)
            # drop packets that are not IPV4_TYPE or IPV6_TYPE
            if eth_type != 0x00000800 and eth_type != 0x000086dd:
                print('dropped')
                continue
            ip_proto = int(row[2])
            ip_flags = int(row[3], 16) >> 12
            ipv6_nxt = int(row[4])
            ipv6_opt = int(row[5])
            tcp_srcport = int(row[6])
            tcp_dstport = int(row[7])
            tcp_flags = int(row[8], 16)
            udp_srcport = int(row[9])
            udp_dstport = int(row[10])
            ground_truth = int(row[11])

            pkt = None
            if (ipv6_nxt == -1):
                pkt = Ether(type=eth_type, src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
                pkt = pkt / IP(dst=addr, proto=ip_proto, flags=ip_flags, len=frame_len, id=ground_truth)
            elif ipv6_nxt >= 0 and ipv6_nxt <= 255:
                pkt = Ether(type=eth_type
                            , src=get_if_hwaddr(iface),
                            dst='ff:ff:ff:ff:ff:ff') / IPv6(
                    src='::1',
                    dst='::1',
                    nh=ipv6_nxt,
                    plen=frame_len,
                    hlim=ground_truth + 1)
                if ipv6_opt != -1:
                    jumbo = Jumbo(jumboplen=int(row[5]))
                    pkt = pkt / IPv6ExtHdrHopByHop(options=jumbo)

            if tcp_srcport != -1 and tcp_dstport != -1:
                pkt = pkt / TCP(dport=tcp_dstport, sport=tcp_srcport, flags=tcp_flags)
            elif udp_srcport != -1 and udp_dstport != -1:
                pkt = pkt / UDP(dport=udp_dstport, sport=udp_srcport)
            pkt = pkt / Raw('\0'*(frame_len-len(pkt)))
            pkt.show2()
            sendp(pkt, iface=iface, verbose=False)
            if (i >= 35):
                break



if __name__ == '__main__':
    main()
