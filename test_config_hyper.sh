table_add ipv4_match to_port_action 10.0.0.0/24 => 1
table_add ipv4_match to_port_action 10.0.1.0/24 => 2
table_add ipv6_match to_port_action ::ffff:0a00:0000/120 => 1
table_add ipv6_match to_port_action ::ffff:0a00:0100/120 => 2

table_set_default dt_level0 to_next_level 1 5 6

table_add dt_level1 to_next_level 0x0001 0x0800->0x0800 0x00000000->0x0000000a => 2 0 2 0
table_add dt_level1 to_next_level 0x0001 0x0800->0x0800 0x0000000a->0xFFFFFFFF => 3 1 3 0
table_add dt_level1 to_next_level 0x0001 0x86DD->0x86DD 0x00000000->0x0000000a => 2 0 2 0
table_add dt_level1 to_next_level 0x0001 0x86DD->0x86DD 0x0000000a->0xFFFFFFFF => 3 1 3 0

table_add dt_level2 set_class 0x0002 0x0a000000->0x0aFFFFFF 0x0x00->0xFFF => 1 0
table_add dt_level2 set_class 0x0002 0x0a000000->0x0aFFFFFF 0x1000->0xFFFFFFFF => 2 0
table_add dt_level2 set_class 0x0002 0x0->0xFFFFFFFF 0x0->0xFFFFFFFF => 3 1

table_add dt_level2 set_class 0x0003 0x0a000000->0x0aFFFFFF 0x00->0xC8 => 4 0
table_add dt_level2 set_class 0x0003 0x0a000000->0x0aFFFFFF 0xC8->0xFFFFFFFF => 5 0
table_add dt_level2 set_class 0x0003 0x0->0xFFFFFFFF 0x0->0xFFFFFFFF => 6 1