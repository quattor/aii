@{ 
Profile to ensure that the kickstart commands and packages section are generated 
@}
object template kickstart_ksdevice_link;
include 'kickstart';

prefix "/system/aii/osinstall/ks";
"version" = "19.31";

prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "link";
