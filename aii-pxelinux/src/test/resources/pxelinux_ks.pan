@{ 
Base pxelinux_ks data
@}
template pxelinux_ks;

include 'pxelinux_no_append';

# at least 1 ks entry to trigger ks append lines
prefix "/system/aii/osinstall/ks";
"node_profile" = "https://somewhere/node_profile";

prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "eth0";
"kslocation" = "http://server/ks";
