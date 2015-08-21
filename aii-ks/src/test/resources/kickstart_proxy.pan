object template kickstart_proxy;

include 'kickstart';

prefix "/software/components/spma";
# beware of crappy legacy schema
"proxy" = "yes";

"proxyhost" = "proxy.server1,proxy.server2";  # comma-separated list of proxy hosts
"proxyport" = "1234"; # yes, this is a string in the spma schema
"proxytype" = 'forward';
