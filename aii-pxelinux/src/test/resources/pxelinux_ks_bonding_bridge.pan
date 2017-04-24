@{
Profile to test kickstart bonding and bridge configuration
@}
object template pxelinux_ks_bonding_bridge;

include 'pxelinux_ks';

prefix "/system/network";
"interfaces/br0/ip" = "1.2.3.0";
"interfaces/br0/netmask" = "255.255.255.0";

"interfaces/bond0/bridge" = "br0";
"interfaces/bond0/bonding_opts" = dict(
    "opt1", "val1",
    "opt2", "val2",
    );

"interfaces/eth0" = dict(
    "bootproto", "none",
    "master", "bond0"
    );
"interfaces/eth1" = dict(
    "bootproto", "none",
    "master", "bond0"
    );

prefix "/system/aii/osinstall/ks";
# to check static ip generation,
# static ip not strictly needed for pxelinux bonding config
"version" = "19.31"; # EL7 for static; dhcp should work with EL6 / "13.21"
"bootproto" = "static";
