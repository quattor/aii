# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

# Template containing OS configuration and default values.

template quattor/aii/ks/variants/fedora14;

# Remove deprecated options 
"/system/aii/osinstall/ks/mouse" = null;
"/system/aii/osinstall/ks/langsupport" = null;
"/system/aii/osinstall/ks/packages_args" = list("--ignoremissing");

#add needed packages for @INC at post-install step :
"/system/aii/osinstall/ks/extra_packages" ?= push("perl-CAF", "perl-LC", "perl-AppConfig",);

