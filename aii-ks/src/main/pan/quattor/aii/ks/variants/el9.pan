# Template containing OS configuration and default values.

template quattor/aii/ks/variants/el9;

# Remove deprecated options
prefix "/system/aii/osinstall/ks";
"mouse" = null;
"langsupport" = null;
"packages_args" = list("--ignoremissing");

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
