# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

@{Structure for the component generating kickstart files.}

declaration template quattor/aii/ks/schema;

include 'pan/types';

@documentation{
    X configuration on the KS file.
}
type structure_ks_ksxinfo = {
    @{Graphics card driver}
    "card"		? string
    "monitor"	? string
    "noprobe"	? string
    "vsync"		? long
    "hsync"		? long
    "defaultdesktop" : string with match (SELF, "^(GNOME|KDE)$")
    "resolution"	: string with match (SELF, "^[0-9]+x[0-9]+$")
    "videoram"	? long
    "startxonboot"	: boolean = true
    "depth"		: long (1..32) = 24
};

type string_ksservice = string with match (SELF, "^(ssh|telnet|smtp|http|ftp)$");

@documentation{
    Configure the firewall at installation-time.
}
type structure_ks_ksfirewall = {
    "enabled"	: boolean = true
    "trusted"	? string []
    "services"	: string_ksservice[] = list ("ssh")
    "ports"		: long[] = list (7777)
};

@documentation{
    Log to syslog. Anaconda syslog uses UDP
}
type structure_ks_logging = {
    @{when host is defined, anaconda syslog will be configured}
    "host" ? type_hostname
    "port" : type_port = 514
    "level" ? string with match(SELF, "^(debug|warning|error|critical|info)$")
    @{redirect AII ks logfile to console }
    "console" : boolean = true
    @{send AII ks logfile to host/port}
    "send_aiilogs" : boolean = false
    # use legacy defaults
    @{send_aiilogs via bash or netcat}
    "method" : string = 'netcat' with match(SELF, '^(bash|netcat)$')
    @{send_aiilogs via tcp or udp}
    "protocol" : string = 'udp' with match(SELF, '^(tcp|udp)$')
} with {
    (! SELF['send_aiilogs']) || is_defined(SELF['host'])
};

@documentation{
    Information needed for creating the Kickstart file
    Optional hooks pre_install, post_install, post_reboot and install
    for user customization are under /system/ks/hooks/.
}
type structure_ks_ks_info = {
    "ackurl"	: type_absoluteURI
    "acklist"	? type_absoluteURI[]
    "auth" : string[] = list ("enableshadow", "passalgo=sha512")
    "bootloader_location" : string = "mbr"
    "bootloader_append" ? string
    "bootloader_password" ? string
    "bootdisk_order" ? string[] # From DESYs template
    "clearmbr"	: boolean = true
    "enable_service" ? string[]
    "enable_sshd"   : boolean = false
    "clearpart"	? string []
    "driverdisk"	? type_absoluteURI[]
    "email_success" : boolean = false
    "firewall"	? structure_ks_ksfirewall
    "installtype"	: string
    "installnumber" ? string
    "lang"		: string = "en_US.UTF-8"
    # TODO: how would you set --default=your_lang in ks?
    @{If you use more than one language, mark the default one with --default your_lang}
    "langsupport"	? string [] = list ("en_US.UTF-8")
    "logging"	? structure_ks_logging
    "mouse"		? string
    "bootproto"	: string with match (SELF, "static|dhcp")
    "keyboard"	: string = "us"
    "node_profile"	: type_absoluteURI
    "rootpw"	: string
    "osinstall_protocol" : string with match (SELF, "^(https?|nfs|ftp)$")
    "packages"	: string []
    "pre_install_script" ? type_absoluteURI
    "post_install_script" ? type_absoluteURI
    "post_reboot_script" ? type_absoluteURI
    "repo"          ? string[]
    "timezone"	: string
    "selinux"	? string with match (SELF, "disabled|enforcing|permissive")
    "xwindows"	? structure_ks_ksxinfo
    "disable_service" ? string[]
    "ignoredisk"    ? string[]
    @{Base packages needed for a Quattor client to run (CAF, CCM...)}
    "base_packages" : string[]
    @{Repositories to disable while SPMA is not available}
    "disabled_repos" : string[] = list()
    "packages_args" : string[] = list("--ignoremissing","--resolvedeps")
    "end_script" :  string = ""
    "part_label" : boolean = false # Does the "part" stanza support the --label option?
    @{Set to true if volgroup statement is required in KS config file (must not be present for SL6+)}
    'volgroup_required' : boolean = false
    @{anaconda version, default is for EL5.0 support}
    'version' : string = '11.1'
    @{use cmdline instead of text mode}
    'cmdline' ? boolean
    @{agree with EULA (EL7+)}
    'eula' ? boolean
    'packagesinpost' ? boolean
    @{configure bonding}
    'bonding' : boolean = true
    'lvmforce' ? boolean
    'init_spma_ignore_deps' ? boolean
};
