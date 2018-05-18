unique template kickstart_static_ip;

include 'kickstart';

prefix "/system/aii/osinstall/ks";
"version" = "19.31";
"enable_sshd" = true;
"bootproto" = "static";
"cmdline" = true;
"eula" = true;

