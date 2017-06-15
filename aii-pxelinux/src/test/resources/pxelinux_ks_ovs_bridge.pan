@{
Profile to test kickstart single interface ovs_bridge configuration
@}
object template pxelinux_ks_ovs_bridge;

include 'pxelinux_ks';

prefix "/system/network";
"interfaces/br0/ip" = "1.2.3.0";
"interfaces/br0/netmask" = "255.255.255.0";
"interfaces/br0/OVSBridge" = "1.2.3.0";

"interfaces/eth0/ovs_bridge" = "br0";

prefix "/system/aii/osinstall/ks";
# to check static ip generation,
# static ip not strictly needed for pxelinux bonding config
"version" = "19.31"; # EL7 for static; dhcp should work with EL6 / "13.21"
"bootproto" = "static";
