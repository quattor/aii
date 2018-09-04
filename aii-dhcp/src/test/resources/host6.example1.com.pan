object template host6.example1.com;

include 'dhcp';


"/hardware/cards/nic/eth0/hwaddr" = "00:11:22:33:44:cc";

prefix "/system/network";

"hostname" = "host6";
"domainname" = "example1.com";
"interfaces/eth0" = dict("ip", "10.11.2.6", "netmask", "255.255.255.0");
