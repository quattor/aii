@{
Profile to test kickstart single interface ovs_bridge configuration
@}
object template kickstart_ovs_bridge;

include 'kickstart';

prefix "/system/network";
"interfaces/br0/ip" = "1.2.3.0";
"interfaces/br0/netmask" = "255.255.255.0";
"interfaces/br0/OVSBridge" = "1.2.3.0";

"interfaces/eth0/ovs_bridge" = "br0";

prefix "/system/aii/osinstall/ks";
"bootproto" = "static";
"version" = "13.21";
