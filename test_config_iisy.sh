table_add lookup_eth_type set_eth_type_code 0x0800&&&0xFFFF => 1 0
table_add lookup_eth_type set_eth_type_code 0x0806&&&0xFFFF => 2 0
table_add lookup_eth_type set_eth_type_code 0x86DD&&&0xFFFF => 3 0

table_add lookup_ip_proto set_ip_proto_code 0x06&&&0xFF => 1 0
table_add lookup_ip_proto set_ip_proto_code 0x11&&&0xFF => 2 0

table_add lookup_dstport set_dstport_code 0x00&&&0xF000 => 1 0

table_add lookup_code set_output_port 0x010000 => 1
table_add lookup_code set_output_port 0x008800 => 1
table_add lookup_code set_output_port 0x008400 => 1
table_add lookup_code set_output_port 0x008401 => 2
table_add lookup_code set_output_port 0x008801 => 2
