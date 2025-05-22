# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

unique template quattor/aii/${project.artifactId}/schema;

# Information needed for creating the Kickstart file
type structure_dhcp_dhcp_info = {
    "tftpserver" ? string
    "filename" ? string
    "options" ? string{}
};

bind "/system/aii/${project.artifactId}" = structure_dhcp_dhcp_info;
