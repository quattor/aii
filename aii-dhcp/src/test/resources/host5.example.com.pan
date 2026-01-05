object template host5.example.com;

include 'dhcp';


"/hardware/cards/nic/eth0/hwaddr" = "00:11:22:33:44:cc";

prefix "/system/network";

"hostname" = "host5";
"domainname" = "example.com";
"interfaces/eth0" = dict("ip", "10.11.0.5", "netmask", "255.255.255.0");
