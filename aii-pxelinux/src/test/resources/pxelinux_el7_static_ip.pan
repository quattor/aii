object template pxelinux_el7_static_ip;

include 'pxelinux';

prefix "/system/aii/nbp/pxelinux";
"setifnames" = true;

prefix "/system/aii/osinstall/ks";
"version" = "7.0";
"bootproto" = "static";
"enable_sshd" = true;
"logging/host" = "logserver";
"logging/port" = 514;
"logging/level" = "debug";
