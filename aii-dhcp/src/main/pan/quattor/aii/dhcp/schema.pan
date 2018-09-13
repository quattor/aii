# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

unique template quattor/aii/dhcp/schema;

type structure_dhcp_module_info = {
    "enabled" ? boolean
};

type structure_dhcp_dhcp_info = {
    @{TFTP server to use for this node, instead of the host where AII runs}
    "tftpserver" ? string
    @{Name of the file to boot}
    "filename" ? string
    @{
      Custom options to include in the host definition. Note: if the type
      of an option requires quoting, then the quotes must be included in
      the value you specify in templates.
    }
    "options" ? string{}
    @{Verify hostname in DNS}
    "verifyhostname" ? boolean
};
