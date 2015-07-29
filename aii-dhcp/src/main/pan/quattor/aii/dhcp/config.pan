# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
template quattor/aii/${project.artifactId}/config;

include 'quattor/aii/${project.artifactId}/schema';

# TFTP server
# This is optional. Only it is necessary if your TFTP server is running on
# a different machine than the DHCP server
#
# "/system/aii/dhcp/options/tftpserver" = "tftp.mydomain.org"
#
variable AII_DHCP_TFTPSERVER ?= null;
"/system/aii/dhcp/options/tftpserver" ?= AII_DHCP_TFTPSERVER;

# Additional DHCP options (optional).
# Warning: They will be added in the host declaration of dhcpd.conf file, so
# do not forget the ';' at the end
#
#"/system/aii/dhcp/addoptions" = "options blu-blo-bli bla;";
#
variable AII_DHCP_ADDOPTIONS ?= null;
"/system/aii/dhcp/options/addoptions" ?= AII_DHCP_ADDOPTIONS;
