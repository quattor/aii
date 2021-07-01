@{
Base configuration for pxelinux tests.
To be included in object templates actually used with tests.
@}
unique template pxelinux_config_common;

include 'quattor/aii/pxelinux/schema';

bind "/system/aii/nbp/pxelinux" = structure_pxelinux_pxe_info;

prefix "/system/network";
"hostname" = 'x';
"domainname" = 'y';
"nameserver/0" = 'nm1';
"nameserver/1" = 'nm2';
"default_gateway" = "133.2.85.1";
"interfaces/eth0" = dict(
    "ip", "133.2.85.234",
    "netmask", "255.255.255.0",
    );
"interfaces/eth1" = dict(
    "onboot", "no",
    );

prefix "/hardware/cards/nic";
"eth0/hwaddr" = "00:11:22:33:44:55";
"eth1/hwaddr" = "00:11:22:33:44:66";

prefix "/system/aii/nbp/pxelinux";
"initrd" = "path/to/initrd";
"kernel" = 'mykernel';
"label" = "Scientific Linux 6x (x86_64)";
"ksdevice" = "eth0";
"kslocation" = "http://server/ks";
"firmware" = "firmware.cfg";
"livecd" = "livecd.cfg";
"rescue" = "rescue.cfg";
