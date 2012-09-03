#!/usr/bin/perl -w
# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
################################################################################
#
# When a client node finishes to install itself, it should send a
# notification message to the AII server. In this way, the AII server
# can mark the node to boot from its local hard disk the next time it reboots.
# If the client fails to send the notification message, it will get
# reinstalled during the next reboot.
#
################################################################################

use strict;
use Socket;

#
# Beginning sequence for EDG initialization
#
BEGIN {
    # use perl libs in /usr/lib/perl
    unshift(@INC, '/usr/lib/perl');
    unshift(@INC,'/opt/edg/lib/perl');
}

print "Content-type: text/plain\n\n";

#
# Check if the web server returned client address
#
if (!defined ($ENV{REMOTE_ADDR})) {
    print "[ERROR] aii-installack: hostname not defined\n";
    exit 0;
}

#
# Try to get client address
#
my $packed_address = pack('C4', split(/\./ ,$ENV{REMOTE_ADDR}));
my $host = gethostbyaddr($packed_address, AF_INET);
my ($cdburl, $config);
if ($host eq '') {
    print "[ERROR] aii-installack: invalid hostname ($ENV{REMOTE_ADDR})\n";
    exit 0;
}

if ($ENV{QUERY_STRING}) {
    use CGI;
    my $query = CGI->new;
    $host = $query->param ('node') if $query->param ('node');
    $cdburl = $query->param ('cdburl') if $query->param ('cdburl');
    $config = $query->param ('bootconf') if $query->param ('bootconf');
}



#
# Run shellfe via sudo
#
my @command = ("/usr/bin/sudo", "/usr/sbin/aii-shellfe",
               "--boot", $host, "--nodhcp", "--noosinstall");
push (@command, '--cdburl', $cdburl) if $cdburl;
push (@command, '--bootconfig', $config) if $config;
if (system (@command)) {
    print "[ERROR] aii-installack: error while executing command @command";
} else {
    print "[INFO] aii-installack: host '$host' configured " .
          "to boot from local disk\n";
}
