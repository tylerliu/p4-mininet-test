table_add ipv4_match to_port_action 10.0.0.0/24 => 1
table_add ipv4_match to_port_action 10.0.1.0/24 => 2
table_add ipv6_match to_port_action fe80::204:ff:fe00:0/128 => 1
table_add ipv6_match to_port_action fe80::204:ff:fe00:1/128 => 2

table_set_default dt_level0 to_next_level 1 1 2

table_add dt_level1 to_next_level 0x0001 0x0800->0x0800 0x00000000->0x0000000a => 2 0 5 0
table_add dt_level1 to_next_level 0x0001 0x0800->0x0800 0x0000000a->0xFFFFFFFF => 3 0 4 0
table_add dt_level1 to_next_level 0x0001 0x86DD->0x86DD 0x00000000->0x0000000a => 2 0 5 0
table_add dt_level1 to_next_level 0x0001 0x86DD->0x86DD 0x0000000a->0xFFFFFFFF => 3 0 4 0

table_add dt_level2 set_class 0x0002 0x00000000->0xFFFFFFFF 0x00->0xFFF => 4 0
table_add dt_level2 set_class 0x0002 0x00000000->0xFFFFFFFF 0x1000->0xFFFFFFFF => 8 0
table_add dt_level2 set_class 0x0002 0x00000000->0xFFFFFFFF 0x0->0xFFFFFFFF => 12 1

table_add dt_level2 set_class 0x0003 0x00000000->0xFFFFFFFF 0x00->0xC8 => 16 0
table_add dt_level2 set_class 0x0003 0x00000000->0xFFFFFFFF 0xC8->0xFFFFFFFF => 20 0
table_add dt_level2 set_class 0x0003 0x00000000->0xFFFFFFFF 0x0->0xFFFFFFFF => 24 1