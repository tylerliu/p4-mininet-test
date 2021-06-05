#!/usr/bin/env python
import argparse
import sys
import socket
import random
import struct
from csv import reader
from scapy.all import sendp, send, get_if_list, get_if_hwaddr
from scapy.all import Packet
from scapy.all import Ether, IP, UDP, TCP, IPv6, IPv6ExtHdrHopByHop

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

    if len(sys.argv)<3:
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
            ip_proto = int(row[2])
            # TODO: fail to set ip_flags; tests on data with ipv6_nxt, ipv6_opt
            ip_flags = int(row[3], 16)
            ipv6_nxt = int(row[4])
            ipv6_opt = row[5]
            tcp_srcport = int(row[6])
            tcp_dstport = int(row[7])
            tcp_flags = int(row[8], 16)
            
            udp_srcport = int(row[9])
            udp_dstport = int(row[10])
            # TODO: GT?
            message = "This is message: "+ str(i)
            
            pkt = Ether(type=eth_type, src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
            pkt = pkt /IP(dst=addr, proto=ip_proto, flags=ip_flags, len=frame_len)
            pkt[IP].flags=ip_flags
            if ipv6_nxt >= 0 and ipv6_nxt <= 255:
                pkt = pkt / IPv6(nh=ipv6_nxt)
            if ipv6_opt != '-1':
                pkt = pkt / IPv6ExtHdrHopByHop(options=ipv6_opt)

            if tcp_srcport != -1 and tcp_dstport != -1:
                pkt = pkt / TCP(dport=tcp_dstport, sport=tcp_srcport, flags=tcp_flags) / message
            elif udp_srcport != -1 and udp_dstport != -1:
                pkt = pkt / UDP(dport=udp_dstport, sport=udp_srcport) / message
            else:
                print("Invalid Port Numbers in row:" + str(row))
            pkt.show2()
            sendp(pkt, iface=iface, verbose=False)
            if(i>=10):
                break;



if __name__ == '__main__':
    main()