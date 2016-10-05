object template pxelinux_ks_block;

include 'pxelinux_ks';

prefix "/system/aii/nbp/pxelinux";
"updates" = "http://somewhere/somthing/updates.img";
"append" = "inst.stage2=http://LOCALHOST/stage2.img";
