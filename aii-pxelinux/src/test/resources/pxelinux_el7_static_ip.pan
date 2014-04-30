object template pxelinux_el7_static_ip;

include 'pxelinux';

prefix "/system/aii/nbp/pxelinux";
"setifnames" = true;
"updates" = "http://somewhere/somthing/updates.img";

prefix "/system/aii/osinstall/ks";
"version" = "19.31";
"bootproto" = "static";
"enable_sshd" = true;
"cmdline" = true;
"logging/host" = "logserver";
"logging/port" = 514;
"logging/level" = "debug";
