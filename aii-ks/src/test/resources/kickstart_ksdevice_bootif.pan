@{ 
Profile to ensure that the kickstart commands and packages section are generated 
@}
object template kickstart_ksdevice_bootif;
include 'kickstart';

prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "bootif";
