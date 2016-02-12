# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

# Template adding aii-freeipa rpm to the configuration

unique template quattor/aii/freeipa/rpms;

"/software/packages"=pkg_repl("aii-freeipa","${no-snapshot-version}-${rpm.release}","noarch");
