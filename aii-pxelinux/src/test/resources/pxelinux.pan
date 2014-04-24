@{ 
Base pxelinux data
@}
template pxelinux;

"/system/network/hostname" = 'x';
"/system/network/domainname" = 'y';

prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "eth0";
"initrd" = "path/to/initrd";
"kernel" = 'mykernel';
"kslocation" = "http://server/ks";
"label" = "kernel label";
