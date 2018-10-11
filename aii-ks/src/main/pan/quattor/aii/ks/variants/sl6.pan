# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

# Template containing OS configuration and default values.

template quattor/aii/ks/variants/sl6;

prefix "/system/aii/osinstall/ks";

# Remove deprecated options
"mouse" = null;
"langsupport" = null;

"part_label" = true;
"volgroup_required" = false;

"packages" = {
    append('perl-parent');
    append('perl-GSSAPI');
    append('perl-Template-Toolkit');
    SELF;
};

"version" = "13.21";

"logging/method" = 'netcat';
"logging/protocol" = 'udp';
