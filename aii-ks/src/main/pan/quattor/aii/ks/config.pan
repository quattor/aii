# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

# Template containing the Kickstart-related configuration and default
# values.

template quattor/aii/ks/config;

include {'quattor/aii/ks/schema'};

variable AII_DOMAIN ?= value('/system/network/domainname');
variable AII_HOSTNAME ?= value('/system/network/hostname');

@{
desc = when true, default list of disks whose partitions must be cleared contains only disks with attribute boot defined to true.\
 When false, this list contains all disks managed by Quattor (defined in /system/blockdevices/physical_devs).
values = true or false
default = false
required = no
}
variable AII_OSINSTALL_CLEARPART_BOOT_ONLY ?= false;

#
# OS installation server has to be defined via variable AII_OS_INSTALL_SRV.
# No default value is meaningfull. Display an error if not defined previously.
# Also ensure that AII_OSINSTALL_SRV has no  trailing /.
#
variable AII_OSINSTALL_SRV ?= {
    error("You need to define variable  AII_OSINSTALL_SRV (generally the Quattor server) "
          + " in order to use AII templates");
};

variable AII_OSINSTALL_SRV = {
  toks = matches(AII_OSINSTALL_SRV,'^(.*)/$');
  if ( length(toks) < 2 ) {
    return(SELF);
  } else {
    return(toks[1]);
  };
};


#
# KS configuration files server
# defaults to OS installation server
#
variable AII_KS_SRV ?= AII_OSINSTALL_SRV;

#
# CDB server, needed to retrieve the node profile
# defaults to OS installation server
#
variable AII_CDB_SRV ?= AII_OSINSTALL_SRV;


#
variable AII_OSINSTALL_PATH ?= undef;

#
# Installation protocol (http or nfs)
# defaults to http
#
variable AII_OSINSTALL_PROTOCOL ?= if ( exists("/system/aii/osinstall/ks/osinstall_protocol") ) {
                                     error('Use AII_OSINSTALL_PROTOCOL to define installation protocol');
                                   } else {
                                     return('http');
                                   };
"/system/aii/osinstall/ks/osinstall_protocol" ?= AII_OSINSTALL_PROTOCOL;
# Be sure AII_OSINSTALL_PROTOCOL matches osinstall_protocol in case the latter was defined first.
# For backward compatibility, as in previous versions, osinstall_protocol was explicitly defined by sites.
variable AII_OSINSTALL_PROTOCOL = value('/system/aii/osinstall/ks/osinstall_protocol');


#
# Define OS installation path based on OS version
# If AII_OSINSTALL_ROOT,AII_OS_VERSION and AII_OSINSTALL_PATH are undefined, assume
# /system/aii/osinstall/ks/installtype has been defined explicitly
# (backward compatibility, deprecated). If not, quattor/aii/config will handle it.
#
variable AII_OSINSTALL_ROOT ?= undef;
variable AII_OSINSTALL_OS_VERSION ?= undef;

# AII_OSINSTALL_SUBURL allows to specify a sub-url under root/version
# (e.g. /base)

variable AII_OSINSTALL_SUBURL ?= undef;
variable AII_OSINSTALL_PATH ?= {
    if ( is_defined(AII_OSINSTALL_ROOT) && is_defined(AII_OSINSTALL_OS_VERSION) ) {
	    path = AII_OSINSTALL_ROOT + '/' + AII_OSINSTALL_OS_VERSION;
	    if ( is_defined(AII_OSINSTALL_SUBURL) ) {
		    path = path + AII_OSINSTALL_SUBURL;
		};
		return(path);
	} else {
	    return(undef);
	} ;
};

# SElinux default configuration at installation time.
variable AII_OSINSTALL_SELINUX ?= 'disabled';
"/system/aii/osinstall/ks/selinux" ?= AII_OSINSTALL_SELINUX;

#
# Install type and URL (for http or https) or directory (for NFS) 
# with the OS distribution
# For backward compatibility (deprecated), allow installtype to be defined explicicly
# rather than from AII_OSINSTALL_xxx variables.
#
"/system/aii/osinstall/ks/installtype" ?= {
    if ( !exists(AII_OSINSTALL_PATH) || !is_defined(AII_OSINSTALL_PATH) ) {
      error("You need to define the variable AII_OSINSTALL_PATH or AII_OSINSTALL_ROOT "
          + "(OS distribution location on the Quattor server)");
    };
    
    if ( match(AII_OSINSTALL_PROTOCOL,"^https?") )  {
        return("url --url " + AII_OSINSTALL_PROTOCOL + "://" + AII_OSINSTALL_SRV + AII_OSINSTALL_PATH);
    } else if ( match(AII_OSINSTALL_PROTOCOL,"(?i)nfs") ) {
        return("nfs --server " + AII_OSINSTALL_SRV + " --dir " + AII_OSINSTALL_PATH);
    } else {
      error('Unsupported OS installation protocol: '+AII_OSINSTALL_PROTOCOL);
    };
};

#
# Language during installation process
#
variable AII_OSINSTALL_OPTION_LANG ?= "en_US";
"/system/aii/osinstall/ks/lang" ?= AII_OSINSTALL_OPTION_LANG;


#
# Language installed
#
variable AII_OSINSTALL_OPTION_LANG_SUPP ?= list (AII_OSINSTALL_OPTION_LANG);
"/system/aii/osinstall/ks/langsupport" ?= AII_OSINSTALL_OPTION_LANG_SUPP;

#
# Keyboard layout
#
variable AII_OSINSTALL_OPTION_KEYBOARD ?= "us";
"/system/aii/osinstall/ks/keyboard" ?= AII_OSINSTALL_OPTION_KEYBOARD;


#
# Mouse type
#
variable AII_OSINSTALL_OPTION_MOUSE ?= "none";
"/system/aii/osinstall/ks/mouse" ?= AII_OSINSTALL_OPTION_MOUSE;


#
# Time zone
#
variable AII_OSINSTALL_OPTION_TIMEZONE ?= "Europe/Paris";
"/system/aii/osinstall/ks/timezone" ?= AII_OSINSTALL_OPTION_TIMEZONE;


#
# Root Password (for example: aii)
# by default, derived from the account component
#
variable AII_OSINSTALL_ROOTPW ?= value("/software/components/accounts/rootpwd");
"/system/aii/osinstall/ks/rootpw" ?= AII_OSINSTALL_ROOTPW; 


#
# Clear the master boot record?
# default is to clear the boot record
#
variable AII_OSINSTALL_OPTION_CLEARMBR ?= true;
"/system/aii/osinstall/ks/clearmbr" ?= AII_OSINSTALL_OPTION_CLEARMBR;

#
# The location of the bootloader. 
# Valid values are: "mbr", "partition", "none"
# default is "mbr"
#
variable AII_OSINSTALL_OPTION_BOOTLOADER ?= "mbr";
"/system/aii/osinstall/ks/bootloader_location" ?= AII_OSINSTALL_OPTION_BOOTLOADER;

#
# Define list of disks to ignore and list of disks whose partition must be cleared.
# By default, KS ignores all disk that are not managed by Quattor or not flagged as the boot disk
# and partitions are set to be cleared on disks that are not ignored.
# If there is only one disk, assume it is the system disk.
# In addition set the default boot disk order based on the boot property if present.
# Also ensure to add a disk only once to one or the other lists.
# This variable is internal and cannot be redefined by a site: use appropriate variables instead.
#
variable AII_OSINSTALL_DISKS = {
    hd_path = '/hardware/harddisks';
    blockdevices_path = '/system/blockdevices/physical_devs';
    SELF['boot_order'] = list();
    
    # Check if an explicit list of disk to clear was specified
    explicit_clearpath = nlist();
    if ( is_defined(AII_OSINSTALL_OPTION_CLEARPART) ) {
      if ( is_list(AII_OSINSTALL_OPTION_CLEARPART) ) {
        SELF['clearpart'] = AII_OSINSTALL_OPTION_CLEARPART;
        foreach (i;disk;AII_OSINSTALL_OPTION_CLEARPART) {
          explicit_clearpath[disk] = '';
        };
      } else {
        error('AII_OSINSTALL_OPTION_CLEARPART must be a list');
      };
    } else {
      SELF['clearpart'] = list();
    };

    # Check if an explicit list of disk to ignore was specified
    explicit_ignore = nlist();
    if ( is_defined(AII_OSINSTALL_IGNOREDISKS) ) {
      if ( is_list(AII_OSINSTALL_IGNOREDISKS) ) {
        SELF['ignore'] = AII_OSINSTALL_IGNOREDISKS;
        foreach (i;disk;AII_OSINSTALL_IGNOREDISKS) {
          explicit_ignore[disk] = '';
        };
      } else {
        error('AII_OSINSTALL_IGNOREDISKS must be a list');
      };
    } else {
      SELF['ignore'] = list();
    };

    # Retrieve list of defined block devices (meaning disks managed by Quattor)
    if ( path_exists(blockdevices_path) && is_defined(value(blockdevices_path)) ) {
      blockdevices = value(blockdevices_path);
    } else {
      blockdevices= nlist()
    };

    if ( exists(hd_path) && is_defined(value(hd_path)) ) {
      hd_list = value(hd_path);
      foreach (disk; params; hd_list) {
        # A disk explicitly set in clearpart list must not be in ignore list
        if ( (length(hd_list) == 1) ||
             (is_defined(blockdevices[disk]) && !AII_OSINSTALL_CLEARPART_BOOT_ONLY) ||
             is_defined(explicit_clearpath[disk]) ||
             (exists(params['boot']) && params['boot']) ) {
          if ( index(disk,SELF['ignore']) < 0 ) {
            clearpart_enabled = true;
            if ( index(disk,SELF['clearpart']) < 0 ) {
              SELF['clearpart'][length(SELF['clearpart'])] = unescape(disk);
            };
          } else {
            clearpart_enabled = false;
          };
          # Define only if there is an explicit boot property defined, else let undefined
          if ( exists(params['boot']) && params['boot'] ) {
            if ( clearpart_enabled ) {
              SELF['boot_order'][length(SELF['boot_order'])] = unescape(disk);
            } else {
              error('HW description inconsistency: '+disk+' defined as a boot disk but clearing of partitions disabled');
            };
          };
        } else {
          if ( index(disk,SELF['clearpart']) < 0 ) {
            if ( index(disk,SELF['ignore']) < 0 ) {
              SELF['ignore'][length(SELF['ignore'])] = unescape(disk);
            };
          } else {
            debug(disk+' not added to the list of ignored disk as its partitions must be cleared');
          };
        };
      };
    } else {
      debug(TEMPLATE+': no disk defined in hardware configuration');
    };
    debug('Disks to ignore: '+to_string(SELF['ignore']));
    debug('Disks whose partitions must be cleared: '+to_string(SELF['clearpart']));
    SELF;
};

variable AII_OSINSTALL_BOOTDISK_ORDER ?= AII_OSINSTALL_DISKS['boot_order'];

"/system/aii/osinstall/ks/clearpart" ?= AII_OSINSTALL_DISKS['clearpart'];
"/system/aii/osinstall/ks/ignoredisk" ?= AII_OSINSTALL_DISKS['ignore'];
"/system/aii/osinstall/ks/bootdisk_order" ?= AII_OSINSTALL_BOOTDISK_ORDER;

##
## A list of services to be disabled for the first reboot after the ks install
## eg variable AII_OSINSTALL_DISABLE_SERVICE = list("yum","apt","yum-autoupdate");
##
variable AII_OSINSTALL_DISABLE_SERVICE ?= null;
"/system/aii/osinstall/ks/disable_service" ?= AII_OSINSTALL_DISABLE_SERVICE; 


#
# How will we configure the network during the installation?
# Default to 'dhcp'
variable  AII_OSINSTALL_BOOTPROTO ?= 'dhcp';
"/system/aii/osinstall/ks/bootproto" ?= AII_OSINSTALL_BOOTPROTO;

#
# Options for authentication
# defaults to using shadow passwords and MD5 hashing
#
variable AII_OSINSTALL_OPTION_AUTH ?= list ("enableshadow", "enablemd5");
"/system/aii/osinstall/ks/auth" ?= AII_OSINSTALL_OPTION_AUTH;
#
# Firewall
# default is to disable the firewall
#
variable AII_OSINSTALL_OPTION_FIREWALL ?= null;
"/system/aii/osinstall/ks/firewall" ?= AII_OSINSTALL_OPTION_FIREWALL;


#
# Minimal package sets to install
# default list of packages required for the initial installation
#

variable AII_OSINSTALL_PACKAGES ?= list ("openssh",
    "openssh-server",
    "wget",
    "perl-libnet",
    "perl-MIME-Base64",
    "perl-URI",
    "perl-Digest-MD5",
    "perl-libwww-perl",
    "perl-XML-Parser",
    "perl-DBI",
    "perl-Crypt-SSLeay",
    "lsof",
    "perl-IO-String",
    "curl");


"/system/aii/osinstall/ks/packages" ?= AII_OSINSTALL_PACKAGES;

#
# URL CGI script for acknowledge "install successful, do not install on next boot"
#
# Note that in the default value assigned is assumed that the OS installation 
# server is the same as the PXE (DHCP+TFTP) one. 
# If is not true, the following variables should be set to define the PXE server:
#    AII_ACK_SRV : the name of the PXE server
#    AII_ACK_CGI : the location of the acknowledgement script to end the installation
#
# If the variables are undefined, the defaults are set below.
#
variable AII_ACK_SRV ?= AII_OSINSTALL_SRV;
variable AII_ACK_CGI ?= "/cgi-bin/aii-installack.cgi";
"/system/aii/osinstall/ks/ackurl" = 
    "http://" + AII_ACK_SRV + AII_ACK_CGI;


#
# Set the location of the node profile
#
variable AII_USE_CCM ?= exists("/software/components/ccm") && is_defined("/software/components/ccm");
variable AII_PROFILE_PATH ?= "/profiles";
variable AII_OSINSTALL_NODEPROFILE ?= {
    if (AII_USE_CCM) {
        if (exists("/software/components/ccm/profile") && !(value("/software/components/ccm/profile") == '' )) {
            return(value("/software/components/ccm/profile"));
        } else {
            error("Can't find value for the profile url at /software/components/ccm/profile. If you don't use ccm, set the variable AII_USE_CCM to false.");
        };
    } else {
        return("http://" + AII_CDB_SRV + AII_PROFILE_PATH + "/" + OBJECT + ".xml");
    };
};
"/system/aii/osinstall/ks/node_profile" ?= AII_OSINSTALL_NODEPROFILE; 

# Additional packages to be installed before rebooting and thus before
# SPMA runs. Insert here Xen kernels and such stuff.
variable AII_OSINSTALL_EXTRAPKGS ?= null;
"/system/aii/osinstall/ks/extra_packages" ?= AII_OSINSTALL_EXTRAPKGS;

#
# For more details on Kickstart options see RedHat documentation:
# http://www.redhat.com/docs/manuals/enterprise/RHEL-3-Manual/sysadmin-guide/ch-kickstart2.html
#
