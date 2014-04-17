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
"netcat" = true;
"bash" = true; # doesn't do anything, netcat takes preference in module
