table_add ipv4_match to_port_action 10.0.0.0/24 => 1
table_add ipv4_match to_port_action 10.0.1.0/24 => 2
table_add ipv6_match to_port_action fe80::204:ff:fe00:0/64 => 1
table_add ipv6_match to_port_action fe80::204:ff:fe00:1/64 => 2

table_set_default dt_level0 to_next_level 1 6

table_add dt_level1 to_next_level 0x0001 0x00->0x0a => 2 3 0
table_add dt_level1 to_next_level 0x0001 0x0b->0xFFFFFFFF => 3 3 0

table_add dt_level2 set_class 0x0002 0x00->0x3C => 1 0
table_add dt_level2 set_class 0x0002 0x3D->0x64 => 2 0
table_add dt_level2 set_class 0x0002 0x65->0xFFFFFFFF => 3 0

table_add dt_level2 set_class 0x0003 0x00->0xC8 => 4 0
table_add dt_level2 set_class 0x0003 0xC9->0xFFFFFFFF => 5 0