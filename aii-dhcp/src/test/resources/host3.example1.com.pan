object template host3.example1.com;

include 'dhcp';

"/hardware/cards/nic/eth0/hwaddr" = "00:11:22:33:44:88";

prefix "/system/network";

"hostname" = "host3";
"domainname" = "example1.com";
"interfaces/eth0" = dict("ip", "10.11.2.3", "netmask", "255.255.255.0");
