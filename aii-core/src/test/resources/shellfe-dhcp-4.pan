object template shellfe-dhcp-4;

include 'shellfe-dhcp';

"/system/aii/dhcp/options/tftpserver" = 'host0.example.com';
"/system/aii/dhcp/options/addoptions" = 'evenmore';

"/hardware/cards/nic/eth0/hwaddr" = "00:11:22:33:44:99";

