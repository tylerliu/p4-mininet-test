table_add ipv4_match to_port_action 10.0.0.0/24 => 1
table_add ipv4_match to_port_action 10.0.1.0/24 => 2
table_add ipv6_match to_port_action fe80::204:ff:fe00:0/64 => 1
table_add ipv6_match to_port_action fe80::204:ff:fe00:1/64 => 2

table_add lookup_eth_type set_eth_type_code 0x0800&&&0xFFFF => 1 0
table_add lookup_eth_type set_eth_type_code 0x0806&&&0xFFFF => 2 0
table_add lookup_eth_type set_eth_type_code 0x86DD&&&0xFFFF => 3 0

table_add lookup_ip_proto set_ip_proto_code 0x06&&&0xFF => 1 0
table_add lookup_ip_proto set_ip_proto_code 0x11&&&0xFF => 2 0

table_add lookup_dstport set_dstport_code 0x00&&&0xF000 => 1 0

table_add lookup_code set_class 0x010000 => 1
table_add lookup_code set_class 0x008800 => 2
table_add lookup_code set_class 0x008400 => 3
table_add lookup_code set_class 0x008401 => 4
table_add lookup_code set_class 0x008801 => 5
