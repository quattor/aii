object template basic;

"/system/network/hostname" = 'x';
"/system/network/domainname" = 'y.z';

prefix "/hardware/cards/nic";
"eth0/boot" = false;
"eth1/boot" = true;

prefix "/system/network/interfaces";
"eth0/ip" = "1.2.3.4";
"eth1/ip" = "5.6.7.8";


prefix "/system/aii/hooks";
"post_reboot/0" = nlist(
    "module", "aii_freeipa",
    "domain", "z", 
    "server", "ipa.y.z",
    "realm", 'DUMMY',
    "dns", true,
    "disable", true,
);
"remove/0" = value("/system/aii/hooks/post_reboot/0");
