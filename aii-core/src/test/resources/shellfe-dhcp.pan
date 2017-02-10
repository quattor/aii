unique template shellfe-dhcp;

"/system/aii/dhcp/options" = dict();

"/hardware/cards/nic/eth0" = dict(
    "boot", true,
    "driver", "bnx2",
#    "hwaddr", "AA:01:00:80:04:04",
    "maxspeed", 1000,
    "media", "Ethernet",
    "name", "Broadcom NetXtreme II",
    "pxe", true,
);

