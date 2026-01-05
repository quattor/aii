object template host1.example.com;

include 'dhcp';

"/system/aii/dhcp/tftpserver" = 'host0.example.com';
"/system/aii/dhcp/options/default-lease-time" = '259200';

"/hardware/cards/nic/eth0/hwaddr" = "00:11:22:33:44:55";

prefix "/system/network";

"hostname" = "host1";
"domainname" = "example.com";
"interfaces/eth0" = dict("ip", "10.11.0.1", "netmask", "255.255.255.0");
