object template kickstart_noproxy;

include 'kickstart';

prefix "/software/components/spma";
# beware of crappy legacy schema
"proxy" = "no"; 

"proxyhost" = "proxy.server,LOCALHOST";  # comma-separated list of proxy hosts
"proxyport" = "1234"; # yes, this is a string in the spma schema
"proxytype" = 'forward';
