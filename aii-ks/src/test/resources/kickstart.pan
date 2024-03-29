@{
Base kickstart data
@}
template kickstart;

"/system/rootmail" = "root@example.com";

prefix "/system/network";
"hostname" = 'x';
"domainname" = 'y';
"nameserver/0" = 'nm1';
"nameserver/1" = 'nm2';
"default_gateway" = "1.2.3.4";
"interfaces/eth0/ip" = "1.2.3.0";
"interfaces/eth0/netmask" = "255.255.255.0";

prefix "/software/packages";

"{kernel*}/{2.6.32-358.1.el6}/arch/x86_64" = "";
"{kernel-firmware}/{2.6.32-358.1.el6}/arch/noarch" = "";
"{ncm-spma}/{14.2.1-1}/arch/noarch" = "";
"{kernel-module-foo}" = nlist();

prefix "/software/repositories/0";
"name" = "repo0";
"owner" = "me@example.com";
"protocols/0/name" = "http";
"protocols/0/url" = "http://www.example.com";
"gpgcheck" = false;
"repo_gpgcheck" = false;
"gpgkey" = list(
    "file:///path/to/key",
    "https://somewhere/very/very/far",
    "ftp://because/ftp/and/security/go/well/together",
);
"gpgcakey" = "file:///super/ca/key";

prefix "/software/repositories/1";
"name" = "repo1";
"owner" = "me@example.com";
"protocols/0/name" = "http";
"protocols/0/url" = "http://www.example1.com";
"excludepkgs" = list('woo', 'hoo*');
"includepkgs" = list('everything', 'else');

# pxelinux and kickstart couple if bootproto is not dhcp
prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "eth0";

include 'quattor/aii/ks/schema';

bind "/system/aii/osinstall/ks" = structure_ks_ks_info;

prefix "/system/aii/osinstall/ks";
"bootproto" = "dhcp";
"keyboard" = "us";
"lang" = "en_US.UTF-8";
"node_profile" = "https://somewhere/node_profile";
"rootpw" = "veryverysecret";
"osinstall_protocol" = "https";
"ackurl" = "http://ack";
"auth" = list ("enableshadow", "passalgo=sha512");
"bootloader_location" = "mbr";
"bootloader_append" = 'append something';
"bootloader_password" = "$1$ZAOkBwVp$Cs5cO5cfaqzH5AdZ/jpjP/"; # "Quattor"
"clearmbr" = true;
"enable_sshd" = false;
"mail/success" = false;
"mail/smtp" = "smtp.example.com";
"installtype" = "url --url http://baseos";
"timezone" = "Europe/SomeCity";
"ntpservers" = list("10.10.10.10", "0.pool.ntp.org");
"packages" = list("package", "package2");
"packages_args" = list("--ignoremissing","--resolvedeps");
"part_label" = false;
"volgroup_required" = false;


# optional
"enable_service" = list("enable1", "ENABLE2");
"disable_service" = list("disable1", "DISABLE2");
"base_packages" = list("ncm-spma", "kernel-module-foo");
"disabled_repos" = list();
