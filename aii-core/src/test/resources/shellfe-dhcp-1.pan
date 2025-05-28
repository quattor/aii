object template shellfe-dhcp-1;

include 'shellfe-dhcp';

"/system/aii/dhcp/options/tftpserver" = 'host0.example.com';
"/system/aii/dhcp/options/addoptions" = "moremore;\n";
"/system/aii/dhcp/options/less" = 'isless';
"/system/aii/dhcp/filename" = 'smallfile';
"/system/aii/dhcp/verifyhostname" = 'yes';

"/hardware/cards/nic/eth0/hwaddr" = "00:11:22:33:44:55";
