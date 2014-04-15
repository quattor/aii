object template kernel-firmware;

prefix "/software/packages";

"{kernel*}/{2.6.32-358.1.el6}/arch/x86_64" = "";
"{kernel-firmware}/{2.6.32-358.1.el6}/arch/noarch" = "";
"{ncm-spma}/{14.2.1-1}/arch/noarch" = "";

prefix "/system/aii/osinstall/ks";

"base_packages" = list("ncm-spma");
"disabled_repos" = list();
