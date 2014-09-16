@{ 
Profile to ensure that the kickstart commands and packages section are generated 
@}
object template kickstart_ksdevice_mac;
include 'kickstart';

prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "AA:BB:CC:DD:EE:FF";
