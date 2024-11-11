# Template containing OS configuration and default values.

template quattor/aii/ks/variants/el8;

variable AII_OSINSTALL_VERSIONLOCK_PLUGIN ?= 'python3-dnf-plugin-versionlock';

# Remove deprecated options
prefix "/system/aii/osinstall/ks";
"mouse" = null;
"langsupport" = null;
"packages_args" = list("--ignoremissing");

"part_label" = true;
"volgroup_required" = false;
"lvmforce" = true;

# el8
"version" = "33.16";
"enable_sshd" = true;
"cmdline" = true;

"logging/method" = 'bash';
"logging/protocol" = 'tcp';

# rhel
"eula" = true;
# deal with optional repository
"packagesinpost" ?= true;

prefix "/system/aii/nbp/pxelinux";
"setifnames" = true;
