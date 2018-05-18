object template pxelinux_ks_el7_static_ip_ipdev;

include 'pxelinux_ks_static_ip';

prefix "/system/aii/nbp/pxelinux";
"ipdev" = "eth123";

prefix "/system/network/interfaces/eth123";
"ip" = "9.8.7.6";
"netmask" = "255.0.0.0";
