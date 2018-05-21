@{ 
Profile to ensure that the kickstart postreboot code is generated
@}
object template kickstart_postreboot;

include 'kickstart';
prefix "/system/aii/osinstall/ks";
"pxeboot" = true;
