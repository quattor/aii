# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

# Template adding aii-pxelinux rpm to the configuration

unique template quattor/aii/pxelinux/rpms;

"/software/packages"=pkg_repl("aii-pxelinux","1.1.12-1","noarch");

