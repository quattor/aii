################################################################################
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
#
# This file is the standard aii configuration. It only performs some
# validations, combines information that is already available, and 
# set sensible default values.
#
# This file should NOT contain any site or platform customization.
#
################################################################################

unique template quattor/aii/config;

include { 'quattor/functions/network' };
include { 'quattor/functions/filesystem' };
include { 'quattor/aii/schema' };

# First include AII site configuration, if any
variable AII_CONFIG_SITE ?= null;
include {if_exists(to_string(AII_CONFIG_SITE));};

# For convenience
variable AII_DOMAIN ?= value('/system/network/domainname');
variable AII_HOSTNAME ?= value('/system/network/hostname');

# Configure AII plugins
variable AII_OSINSTALL_GEN ?= "quattor/aii/ks/config";
variable AII_NBP_GEN ?= "quattor/aii/pxelinux/config";

# Including the KS generator or equivalent
include { AII_OSINSTALL_GEN};
# Including the PXE generator or equivalent
include { AII_NBP_GEN };



#################################################
# DHCP daemon configuration (legacy from aii v1)
#################################################

#
# TFTP server
# This is optional. Only it is necessary if your TFTP server is running on
# a different machine than the DHCP server
#
# "/system/aii/dhcp/options/tftpserver" = "tftp.mydomain.org"
#
variable AII_DHCP_TFTPSERVER ?= null;
"/system/aii/dhcp/options/addoptions" ?= AII_DHCP_TFTPSERVER;

#
# Additional DHCP options (optional).
# Warning: They will be added in the host declaration of dhcpd.conf file, so 
# do not forget the ';' at the end
#
#"/system/aii/dhcp/addoptions" = "options blu-blo-bli bla;";
#
variable AII_DHCP_ADDOPTIONS ?= null;
"/system/aii/dhcp/options/addoptions" ?= AII_DHCP_ADDOPTIONS;


###################################
# End of DHCP daemon configuration
###################################

