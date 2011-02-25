# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
# Structure for the component generating kickstart files.

unique template quattor/aii/ks/schema;

# X configuration on the KS file. Might deserve a component for
# itself.
type structure_ks_ksxinfo = {
	"card"		? string # Graphics card driver
	"monitor"	? string #
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

# Information needed for configuring the firewall at installation-time.
type structure_ks_ksfirewall = {
	"enabled"	: boolean = true
	"trusted"	? string []
	"services"	: string_ksservice[] = list ("ssh")
	"ports"		: long[] = list (7777)
};

# Information needed for creating the Kickstart file
type structure_ks_ks_info = {
	"ackurl"	: type_absoluteURI
	"auth"		: string[] = list ("enableshadow", "enablemd5")
	"bootloader_location" : string = "mbr"
	"bootloader_append" ? string
	"bootdisk_order" ? string[] # From DESYs template
	"clearmbr"	: boolean = true
	"clearpart"	? string []
	"driverdisk"	? type_absoluteURI[]
	"email_success" : boolean = false
	"firewall"	? structure_ks_ksfirewall
	"installtype"	: string
	"lang"		: string = "en_US.UTF-8"
	# If you use more than one languages, mark the default one with "--default=your_lang"	
	"langsupport"	: string [] = list ("en_US.UTF-8")
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
	"timezone"	: string
	"selinux"	? string with match (SELF, "disabled|enforcing|permissive")
	"xwindows"	? structure_ks_ksxinfo
	"disable_service" ? string[]
	"ignoredisk"    ? string[]
	# Additional packages to be installed before the reboot, and
	# thus, before SPMA runs
	"extra_packages" ? string[]
	# Hooks for user customization are under: /system/ks/hooks/{pre_install,
	# post_install, post_reboot and install}. They
	# are optional.

};

bind "/system/aii/osinstall/ks" = structure_ks_ks_info;
