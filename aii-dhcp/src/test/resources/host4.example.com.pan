object template host4.example.com;

include 'dhcp';

"/system/aii/dhcp/tftpserver" = 'host0.example.com';
"/system/aii/dhcp/filename" = 'http://BOOTSRVIP/bootimage';
"/system/aii/dhcp/options/default-lease-time" = '259200';
"/system/aii/dhcp/options/dhcp-message" = '"Quoted string"';
"/system/aii/dhcp/options/domain-name-servers" = '8.8.4.4,8.8.8.8';

"/hardware/cards/nic/eth0/hwaddr" = "00:11:22:33:44:99";

prefix "/system/network";

"hostname" = "host4";
"domainname" = "example.com";
"interfaces/eth0" = dict("ip", "10.11.0.4", "netmask", "255.255.255.0");
