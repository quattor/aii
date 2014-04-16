@{ 
Base kickstart datae
@}
template kickstart;

"/system/network/hostname" = 'x';
"/system/network/domainname" = 'y';

prefix "/software/packages";

"{kernel*}/{2.6.32-358.1.el6}/arch/x86_64" = "";
"{kernel-firmware}/{2.6.32-358.1.el6}/arch/noarch" = "";
"{ncm-spma}/{14.2.1-1}/arch/noarch" = "";
"{kernel-module-foo}" = nlist();


# pxelinux and kickstart couple if bootproto is not dhcp
prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "eth0";

prefix "/system/aii/osinstall/ks";
"bootproto" = "dhcp"; 
"keyboard" = "us";
"lang" = "en_US.UTF-8";
"node_profile" = "https://somewhere/node_profile";
"rootpw" = "veryverysecret";
"osinstall_protocol" = "https";
"ackurl" = "http://ack";
"auth" = list ("enableshadow", "enablemd5");
"bootloader_location" = "mbr";
"clearmbr" = true;
"enable_sshd" = false;
"email_success" = false;
"installtype" = "url --url http://baseos";
"timezone" = "Europe/SomeCity";
"packages" = list("package", "package2");
"packages_args" = list("--ignoremissing","--resolvedeps");
"end_script" = "EENNDD";
"part_label" = false;
"volgroup_required" = false;


# optional
"enable_service" = list("enable1", "ENABLE2");
"disable_service" = list("disable1", "DISABLE2");
"base_packages" = list("ncm-spma", "kernel-module-foo");
"disabled_repos" = list();
