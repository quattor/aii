unique template shellfe-dhcp;

"/system/aii/dhcp/options" = dict();

"/hardware/cards/nic/eth0" = dict(
    "boot", true,
    "driver", "bnx2",
    # "hwaddr", "AA:01:00:80:04:04",
    "maxspeed", 1000,
    "media", "Ethernet",
    "name", "Broadcom NetXtreme II",
    "pxe", true,
);

prefix "/system/network";
"hostname" = "host5";
"domainname" = "example2.com";

prefix "interfaces";
"eth0/ip" = "10.11.3.5";
