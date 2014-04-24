object template pxelinux_logging;

include 'pxelinux';

prefix "/system/aii/osinstall/ks/logging";
"host" = "logserver";
"port" = 514;
"level" = "debug";
