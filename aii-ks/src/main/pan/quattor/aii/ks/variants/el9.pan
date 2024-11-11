# Template containing OS configuration and default values.

template quattor/aii/ks/variants/el9;

variable AII_OSINSTALL_VERSIONLOCK_PLUGIN ?= 'python3-dnf-plugin-versionlock';

# Remove deprecated options
prefix "/system/aii/osinstall/ks";
"mouse" = null;
"langsupport" = null;
"packages_args" = list("--ignoremissing");

# Required by perl-CDB_File
"packages" = append("perl-English");
# Required by some Quattor components and must be installed before
# /etc/init.d is created by something else (e.g. a Quattor package)
"packages" = append("chkconfig");
"packages" = append("initscripts");

"part_label" = true;
"volgroup_required" = false;
"lvmforce" = true;

# el9
"version" = "34.25";
"enable_sshd" = true;
"cmdline" = true;

"logging/method" = 'bash';
"logging/protocol" = 'tcp';

# rhel
"eula" = true;

"packagesinpost" = true;

prefix "/system/aii/nbp/pxelinux";
"setifnames" = true;
