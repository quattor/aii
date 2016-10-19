object template pxelinux_no_append_block;

include 'pxelinux_no_append';

prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "eth0";
"kslocation" = "http://server/ks";
