# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

# Template adding aii-ks rpm to the configuration

unique template quattor/aii/ks/rpms;

"/software/packages"=pkg_repl("aii-ks","${no-snapshot-version}-${rpm.release}","noarch");
