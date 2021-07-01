object template host2.example.com;

include 'dhcp';

"/system/aii/dhcp/tftpserver" = 'host0.example.com';

"/hardware/cards/nic/eth0/hwaddr" = "00:11:22:33:44:66";

prefix "/system/network";

"hostname" = "host2";
"domainname" = "example.com";
"interfaces/eth0" = dict("ip", "10.11.0.2", "netmask", "255.255.255.0");
