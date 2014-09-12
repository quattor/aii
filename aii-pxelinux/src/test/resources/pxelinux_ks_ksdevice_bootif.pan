@{ 
Profile to ensure that the kickstart commands and packages section are generated 
@}
object template pxelinux_ks_ksdevice_bootif;
include 'pxelinux_ks';

prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "bootif";
