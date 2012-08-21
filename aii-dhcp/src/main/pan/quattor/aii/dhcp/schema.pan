# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

unique template quattor/aii/dhcp/schema;

# Information needed for creating the Kickstart file
type structure_dhcp_dhcp_info = {
	"tftpserver"	? string
	"options"	? string{}
};

bind "/system/aii/dhcp" = structure_dhcp_dhcp_info;
