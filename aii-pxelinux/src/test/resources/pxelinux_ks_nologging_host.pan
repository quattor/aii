object template pxelinux_ks_nologging_host;

include 'pxelinux_ks';

prefix "/system/aii/osinstall/ks/logging";
"host" = null;
"port" = 514;
"level" = "debug";

"method" = 'netcat'; 
"protocol" = 'udp';
