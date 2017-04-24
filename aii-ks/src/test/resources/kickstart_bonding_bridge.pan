@{
Profile to test kickstart bonding and bridge configuration
@}
object template kickstart_bonding_bridge;

include 'kickstart';

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
"bootproto" = "static";
"version" = "13.21";
