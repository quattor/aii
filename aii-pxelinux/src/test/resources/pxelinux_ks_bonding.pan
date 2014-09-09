@{ 
Profile to test kickstart bonding configuration 
@}
object template pxelinux_ks_bonding;

include 'pxelinux_ks';

prefix "/system/network"; 
"interfaces/bond0/ip" = "1.2.3.0";
"interfaces/bond0/netmask" = "255.255.255.0";
"interfaces/bond0/bonding_opts" = nlist(
    "opt1", "val1",
    "opt2", "val2",
    );

"interfaces/eth0" = nlist(
    "bootproto", "none",
    "master", "bond0"
    );
"interfaces/eth1" = nlist(
    "bootproto", "none",
    "master", "bond0"
    );

prefix "/system/aii/osinstall/ks";
# to check static ip generation, 
# static ip not strictly needed for pxelinux bonding config
"version" = "19.31"; # EL7 for static; dhcp should work with EL6 / "13.21" 
"bootproto" = "static"; 
"bonding" = true;
