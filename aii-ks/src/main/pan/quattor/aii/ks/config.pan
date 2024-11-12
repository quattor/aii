# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

@{Template containing the Kickstart-related configuration and default values.}

unique template quattor/aii/ks/config;

include 'quattor/aii/ks/schema';

bind "/system/aii/osinstall/ks" = structure_ks_ks_info;

prefix "/system/aii/osinstall/ks";

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
    error("You need to define variable  AII_OSINSTALL_SRV (generally the Quattor server) " +
            " in order to use AII templates");
};

variable AII_OSINSTALL_SRV = {
    toks = matches(AII_OSINSTALL_SRV, '^(.*)/$');
    if ( length(toks) < 2 ) {
        SELF;
    } else {
        toks[1];
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
variable AII_OSINSTALL_PROTOCOL ?=
    if ( exists("/system/aii/osinstall/ks/osinstall_protocol") ) {
        error('Use AII_OSINSTALL_PROTOCOL to define installation protocol');
    } else {
        'http';
    };
"osinstall_protocol" ?= AII_OSINSTALL_PROTOCOL;
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
variable DEBUG = debug(format('%s: AII_OSINSTALL_ROOT=%s, AII_OSINSTALL_OS_VERSION=%s',
                                OBJECT,
                                AII_OSINSTALL_ROOT,
                                AII_OSINSTALL_OS_VERSION));

# AII_OSINSTALL_SUBURL allows to specify a sub-url under root/version
# (e.g. /base)

variable AII_OSINSTALL_SUBURL ?= undef;
variable AII_OSINSTALL_PATH ?=
    if ( is_defined(AII_OSINSTALL_ROOT) && is_defined(AII_OSINSTALL_OS_VERSION) ) {
        path = AII_OSINSTALL_ROOT + '/' + AII_OSINSTALL_OS_VERSION;
        if ( is_defined(AII_OSINSTALL_SUBURL) ) {
            path = path + AII_OSINSTALL_SUBURL;
        };
        path;
    } else {
        debug('AII_OSINSTALL_ROOT or AII_OSINSTALL_OS_VERSION undefined: cannot define AII_OSINSTALL_PATH');
    };


# SElinux default configuration at installation time.
variable AII_OSINSTALL_SELINUX ?= 'disabled';
"selinux" ?= AII_OSINSTALL_SELINUX;

#
# Install type and URL (for http or https) or directory (for NFS)
# with the OS distribution
# For backward compatibility (deprecated), allow installtype to be defined explicicly
# rather than from AII_OSINSTALL_xxx variables.
#
"installtype" ?= {
    if ( !exists(AII_OSINSTALL_PATH) || !is_defined(AII_OSINSTALL_PATH) ) {
        error("You need to define the variable AII_OSINSTALL_PATH or AII_OSINSTALL_ROOT "
                + "(OS distribution location on the Quattor server)");
    };

    if ( match(AII_OSINSTALL_PROTOCOL, "^https?") )  {
        "url --url " + AII_OSINSTALL_PROTOCOL + "://" + AII_OSINSTALL_SRV + AII_OSINSTALL_PATH;
    } else if ( match(AII_OSINSTALL_PROTOCOL, "(?i)nfs") ) {
        "nfs --server " + AII_OSINSTALL_SRV + " --dir " + AII_OSINSTALL_PATH;
    } else {
        error('Unsupported OS installation protocol: ' + AII_OSINSTALL_PROTOCOL);
    };
};

#
# Language during installation process
#
variable AII_OSINSTALL_OPTION_LANG ?= "en_US";
"lang" ?= AII_OSINSTALL_OPTION_LANG;


#
# Language installed
#
variable AII_OSINSTALL_OPTION_LANG_SUPP ?= list (AII_OSINSTALL_OPTION_LANG);
"langsupport" ?= AII_OSINSTALL_OPTION_LANG_SUPP;

#
# Keyboard layout
#
variable AII_OSINSTALL_OPTION_KEYBOARD ?= "us";
"keyboard" ?= AII_OSINSTALL_OPTION_KEYBOARD;


#
# Mouse type
#
variable AII_OSINSTALL_OPTION_MOUSE ?= "none";
"mouse" ?= AII_OSINSTALL_OPTION_MOUSE;


#
# Time zone
#
variable AII_OSINSTALL_OPTION_TIMEZONE ?= "Europe/Paris";
"timezone" ?= AII_OSINSTALL_OPTION_TIMEZONE;


#
# NTP servers used by Anaconda
#
variable AII_OSINSTALL_OPTION_NTPSERVERS ?= null;
"ntpservers" ?= AII_OSINSTALL_OPTION_NTPSERVERS;


#
# Root Password (for example: aii)
# by default, derived from the account component
#
variable AII_OSINSTALL_ROOTPW ?= value("/software/components/accounts/rootpwd");
"rootpw" ?= AII_OSINSTALL_ROOTPW;


#
# Clear the master boot record?
# default is to clear the boot record
#
variable AII_OSINSTALL_OPTION_CLEARMBR ?= true;
"clearmbr" ?= AII_OSINSTALL_OPTION_CLEARMBR;

#
# The location of the bootloader.
# Valid values are: "mbr", "partition", "none"
# default is "mbr"
#
variable AII_OSINSTALL_OPTION_BOOTLOADER ?= "mbr";
"bootloader_location" ?= AII_OSINSTALL_OPTION_BOOTLOADER;

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
    explicit_clearpath = dict();
    if ( is_defined(AII_OSINSTALL_OPTION_CLEARPART) ) {
        if ( is_list(AII_OSINSTALL_OPTION_CLEARPART) ) {
            SELF['clearpart'] = AII_OSINSTALL_OPTION_CLEARPART;
                foreach (i; disk; AII_OSINSTALL_OPTION_CLEARPART) {
                    explicit_clearpath[disk] = '';
            };
        } else {
            error('AII_OSINSTALL_OPTION_CLEARPART must be a list');
        };
    } else {
        SELF['clearpart'] = list();
    };

    # Check if an explicit list of disk to ignore was specified
    explicit_ignore = dict();
    if ( is_defined(AII_OSINSTALL_IGNOREDISKS) ) {
        if ( is_list(AII_OSINSTALL_IGNOREDISKS) ) {
            SELF['ignore'] = AII_OSINSTALL_IGNOREDISKS;
            foreach (i; disk; AII_OSINSTALL_IGNOREDISKS) {
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
        blockdevices = dict()
    };

    if ( exists(hd_path) && is_defined(value(hd_path)) ) {
        hd_list = value(hd_path);
        foreach (disk; params; hd_list) {
            # A disk explicitly set in clearpart list must not be in ignore list
            if ( (length(hd_list) == 1) ||
                (is_defined(blockdevices[disk]) && !AII_OSINSTALL_CLEARPART_BOOT_ONLY) ||
                is_defined(explicit_clearpath[disk]) ||
                (exists(params['boot']) && params['boot']) ) {
                if ( index(disk, SELF['ignore']) < 0 ) {
                    clearpart_enabled = true;
                    if ( index(disk, SELF['clearpart']) < 0 ) {
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
                        error('HW description inconsistency: ' + disk +
                                ' defined as a boot disk but clearing of partitions disabled');
                    };
                };
            } else {
                if ( index(disk, SELF['clearpart']) < 0 ) {
                    if ( index(disk, SELF['ignore']) < 0 ) {
                        SELF['ignore'][length(SELF['ignore'])] = unescape(disk);
                    };
                } else {
                    debug(disk + ' not added to the list of ignored disk as its partitions must be cleared');
                };
            };
        };
    } else {
        debug(TEMPLATE + ': no disk defined in hardware configuration');
    };
    debug('Disks to ignore: ' + to_string(SELF['ignore']));
    debug('Disks whose partitions must be cleared: ' + to_string(SELF['clearpart']));
    SELF;
};

variable AII_OSINSTALL_BOOTDISK_ORDER ?= AII_OSINSTALL_DISKS['boot_order'];

"clearpart" ?= AII_OSINSTALL_DISKS['clearpart'];
"ignoredisk" ?= AII_OSINSTALL_DISKS['ignore'];
"bootdisk_order" ?= AII_OSINSTALL_BOOTDISK_ORDER;

#
# A list of services to be disabled for the first reboot after the ks install
# eg variable AII_OSINSTALL_DISABLE_SERVICE = list("yum","apt","yum-autoupdate");
#
variable AII_OSINSTALL_DISABLE_SERVICE ?= null;
"disable_service" ?= AII_OSINSTALL_DISABLE_SERVICE;

@{
desc = default boot protocol for installation
values = choice between 'dhcp' or 'static' (see schema)
default = static
required = no
}
variable  AII_OSINSTALL_BOOTPROTO ?= 'static';
"bootproto" ?= AII_OSINSTALL_BOOTPROTO;

#
# Options for authentication
# defaults to using shadow passwords and sha512 hashing
#
variable AII_OSINSTALL_OPTION_AUTH ?= list ("enableshadow", "passalgo=sha512");
"auth" ?= AII_OSINSTALL_OPTION_AUTH;
#
# Firewall
# default is to disable the firewall
#
variable AII_OSINSTALL_OPTION_FIREWALL ?= null;
"firewall" ?= AII_OSINSTALL_OPTION_FIREWALL;


#
# Minimal package sets to install
# default list of packages required for the initial installation
#

variable AII_OSINSTALL_PACKAGES ?= list(
    "curl",
    "lsof",
    "openssh",
    "openssh-server",
    "perl-AppConfig",
    "perl-CDB_File",
    "perl-Crypt-SSLeay",
    "perl-DBI",
    "perl-GSSAPI",
    "perl-IO-String",
    "perl-libwww-perl",
    "perl-Pod-POM",
    "perl-Template-Toolkit",
    "perl-URI",
    "perl-XML-Parser",
    "yum-plugin-priorities",
    "yum-plugin-versionlock",
    "wget",
);


"packages" ?= AII_OSINSTALL_PACKAGES;
"packages" = {
    if (value('/system/aii/osinstall/ks/selinux') == 'disabled') {
        # grubby is used to disable selinux on with kernel parameter
        append('grubby');
        append('-selinux*');
    };
    # SMTP support requires mailx
    if (exists('/system/aii/osinstall/ks/mail/smtp')) {
        append('mailx');
    };
    SELF;
};

"/software/packages" = {
    # mailx is also required so fail/success works after spma runs
    if (exists('/system/aii/osinstall/ks/mail/smtp')) {
        pkg_repl('mailx');
    };
    SELF;
};

#
# URL CGI script for acknowledge "install successful, do not install on next boot"
#
# Note that in the default value assigned is assumed that the OS installation
# server is the same as the PXE (DHCP+TFTP) one.
# If is not true, the following variables should be set to define the PXE server:
#    AII_ACK_SRV : the name of the PXE server
#    AII_ACK_CGI : the location of the acknowledgement script to end the installation
#    AII_ACK_LIST: list of URLs to try if the acknowledgement needs to be sent
#                  to multiple servers. If AII_ACK_LIST is set, then AII_ACK_SRV and
#                  AII_ACK_CGI are not used here.
#
# If the variables are undefined, the defaults are set below.
#
variable AII_ACK_SRV ?= AII_OSINSTALL_SRV;
variable AII_ACK_CGI ?= "/cgi-bin/aii-installack.cgi";
variable AII_ACK_LIST ?= list("http://" + AII_ACK_SRV + AII_ACK_CGI);
"acklist" ?= AII_ACK_LIST;

#
# Set the location of the node profile
#
variable AII_USE_CCM ?= exists("/software/components/ccm") && is_defined("/software/components/ccm");
variable AII_PROFILE_PATH ?= "/profiles";
variable AII_OSINSTALL_NODEPROFILE ?=
    if (AII_USE_CCM) {
        if (exists("/software/components/ccm/profile") && !(value("/software/components/ccm/profile") == '' )) {
            value("/software/components/ccm/profile");
        } else {
            error("Can't find value for the profile url at /software/components/ccm/profile. " +
                    "If you don't use ccm, set the variable AII_USE_CCM to false.");
        };
    } else {
        format("http://%s%s/%s.xml", AII_CDB_SRV, AII_PROFILE_PATH, OBJECT);
    };
"node_profile" ?= AII_OSINSTALL_NODEPROFILE;

# Include OS specific kickstart configuration, if needed
#  - including this at the end allow to undefine tree elements, and remain compatible with other (previous) OSes
#  - allow 2 types of variants : major and minor OS variants. Variants for major OS version are located in the standard configuration
#    (as defined by AII_KS_OS_MAJOR_SPECIFIC_INCLUDE, default value should be appropriate when using QWG templates). Variants for minor
#    OS versions are located into the related OS templates ((as defined by AII_KS_OS_MINOR_SPECIFIC_INCLUDE, default value should be appropriate when using QWG
#    templates).  When both exist, they are both applied.
variable  AII_KS_OS_MAJOR_SPECIFIC_INCLUDE ?=
    if ( is_defined(OS_VERSION_PARAMS['major']) ) {
        if_exists('quattor/aii/ks/variants/' + OS_VERSION_PARAMS['major']);
    } else {
        undef;
    };
include {
    debug('KS specific configuration for OS major version: ' + to_string(AII_KS_OS_MAJOR_SPECIFIC_INCLUDE));
    AII_KS_OS_MAJOR_SPECIFIC_INCLUDE;
};
# Existence of OS_VERSION_PARAMS['minor'] is used a a QWG signature
variable  AII_KS_OS_MINOR_SPECIFIC_INCLUDE ?=
    if ( is_defined(OS_VERSION_PARAMS['minor']) ) {
        if_exists('config/quattor/ks');
    } else {
        undef;
};
include {
    debug('KS specific configuration for OS minor release: ' + to_string(AII_KS_OS_MINOR_SPECIFIC_INCLUDE));
    AII_KS_OS_MINOR_SPECIFIC_INCLUDE;
};

#
# For more details on Kickstart options see RedHat documentation:
# http://www.redhat.com/docs/manuals/enterprise/RHEL-3-Manual/sysadmin-guide/ch-kickstart2.html
# This package list must be properly ordered to satisfy package requirements.
#

variable AII_OSINSTALL_BASE_PACKAGES ?= list(
    'perl-Proc-ProcessTable',
    'perl-Set-Scalar',
    'perl-common-sense',
    'perl-JSON-XS',
    "perl-LC",
    "perl-CAF",
    "ccm",
    "ncm-template",
    "ncm-ncd",
    "ncm-query",
    "ncm-spma",
    "cdp-listend",
    "ncm-cdispd",
);

"base_packages" ?= AII_OSINSTALL_BASE_PACKAGES;

# Define if volgroup statement is required for LVM-based file systems.
# Default is for SL4/5
"volgroup_required" = true;
