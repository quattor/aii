@{
Base pxelinux without append data
@}
template pxelinux_no_append;

include 'quattor/aii/pxelinux/schema';

bind "/system/aii/nbp/pxelinux" = structure_pxelinux_pxe_info;

prefix "/system/network";
"hostname" = 'x';
"domainname" = 'y';
"nameserver/0" = 'nm1';
"nameserver/1" = 'nm2';
"default_gateway" = "1.2.3.4";
"interfaces/eth0/ip" = "1.2.3.0";
"interfaces/eth0/netmask" = "255.255.255.0";

prefix "/hardware/cards/nic";
"eth0/hwaddr" = "00:11:22:33:44:55";
"eth1/hwaddr" = "00:11:22:33:44:66";


prefix "/system/aii/nbp/pxelinux";
"initrd" = "path/to/initrd";
"kernel" = 'mykernel';
"label" = "kernel label";
