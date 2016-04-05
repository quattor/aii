@{ Profile to ensure that the yum_install_packages handles correctly
 kernel and kernel-firmware RPMs.
 @}
object template kickstart_packagesinpost;

include 'kickstart';
prefix "/system/aii/osinstall/ks";
"packagesinpost" = true;
"packages" = append("-notthispackage");
"version" = "19.31"; # to set end section
