@{ 
Profile to ensure that the kickstart commands and packages section are generated 
@}
object template kickstart_logging;

include 'kickstart';

prefix "/system/aii/osinstall/ks/logging";
"host" = "logserver";
"port" = 514;
"level" = "debug";
"console" = true; 

"send_aiilogs" = true;
"method" = 'netcat'; 
"protocol" = 'udp';
