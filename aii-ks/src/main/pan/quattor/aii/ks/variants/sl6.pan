# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

# Template containing OS configuration and default values.

template quattor/aii/ks/variants/sl6;

# Remove deprecated options 
"/system/aii/osinstall/ks/mouse" = null;
"/system/aii/osinstall/ks/langsupport" = null;

"/system/aii/osinstall/ks/end_script" = "%end";
"/system/aii/osinstall/ks/part_label" = true;
"/system/aii/osinstall/ks/volgroup_required" = false;

"/system/aii/osinstall/ks/packages" = {
  SELF[length(SELF)] = 'perl-parent';
  SELF[length(SELF)] = 'perl-GSSAPI';
  SELF[length(SELF)] = 'perl-Template-Toolkit';
  SELF;
};

#add needed packages for @INC at post-install step :
"/system/aii/osinstall/ks/extra_packages" ?= push("perl-CAF", "perl-LC");
