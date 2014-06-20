object template pxelinux_ks_logging;

include 'pxelinux_ks';

prefix "/system/aii/osinstall/ks/logging";
"host" = "logserver";
"port" = 514;
"level" = "debug";
