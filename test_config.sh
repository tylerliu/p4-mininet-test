table_set_default dt_level0 to_next_level 1 6

table_add dt_level1 to_next_level 0x0001 0x00000000->0x0000000a => 2 3 0
table_add dt_level1 to_next_level 0x0001 0x0000000a->0xFFFFFFFF => 3 3 0

table_add dt_level2 to_port_action 0x0002 0x00->0x3C => 1 0
table_add dt_level2 to_port_action 0x0002 0x3C->0x64 => 2 0
table_add dt_level2 to_port_action 0x0002 0x64->0xFFFFFFFF => 1 0

table_add dt_level2 to_port_action 0x0003 0x00->0xC8 => 2 0
table_add dt_level2 to_port_action 0x0003 0xC8->0xFFFFFFFF => 1 0