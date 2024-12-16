# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
template quattor/aii/dhcp/config;

include 'quattor/aii/dhcp/schema';

bind "/system/aii/discovery/dhcp" = structure_dhcp_module_info;

prefix "/system/aii/discovery/dhcp";

@documentation{
    Enable the plugin
}
"enabled" = true;

bind "/system/aii/dhcp" = structure_dhcp_dhcp_info;

prefix "/system/aii/dhcp";

@documentation{
    Override the TFT server for this node
}
variable AII_DHCP_TFTPSERVER ?= null;
"tftpserver" ?= AII_DHCP_TFTPSERVER;

@documentation{
    Additional options to include in the host definition
}
variable AII_DHCP_ADDOPTIONS ?= null;
"options" ?= AII_DHCP_ADDOPTIONS;
