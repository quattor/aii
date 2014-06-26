@{ 
Profile to ensure that the kickstart commands and packages section are generated 
@}

object template kickstart_nologging_just_method_and_protocol;

include 'kickstart';

prefix "/system/aii/osinstall/ks/logging";
"host" = null;
"console" = false; 

"method" = 'netcat'; 
"protocol" = 'udp';
