# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

# Template adding aii-${project.artifactId} rpm to the configuration

unique template quattor/aii/${project.artifactId}/rpms;

"/software/packages" = pkg_repl("aii-${project.artifactId}", "${no-snapshot-version}-${rpm.release}", "noarch");
