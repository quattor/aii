# Template containing OS configuration and default values.

template quattor/aii/ks/variants/rhel7rc;

# Remove deprecated options 
prefix "/system/aii/osinstall/ks";
"mouse" = null;
"langsupport" = null;
"packages_args" = list("--ignoremissing");

"end_script" = "%end";
"part_label" = true;
"volgroup_required" = false;

# el7
"version" = "19.31";
"bootproto" = "static";
"enable_sshd" = true;
"cmdline" = true;

"logging/method" = 'bash'; 
"logging/protocol" = 'tcp';

# rhel
"eula" = true;
# deal with optional repository
"packagesinpost" = true;

prefix "/system/aii/nbp/pxelinux";
"setifnames" = true;

# use updates to fix the reverseproxy issue
#"updates" = "http://some.server/updates-rhel7rc-timeout.img";
