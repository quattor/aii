# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

# Template adding aii-opennebula rpm to the configuration

unique template quattor/aii/opennebula/rpms;

"/software/packages"=pkg_repl("aii-opennebula","${no-snapshot-version}-${rpm.release}","noarch");
