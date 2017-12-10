use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_postreboot);
use NCM::Component::ks;
use CAF::FileWriter;
use Text::Diff;

=pod

=head1 SYNOPSIS

Tests for the C<kscommands> method with emphasis on postreboot.

=cut

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kickstart_postreboot');

my $fh = CAF::FileWriter->new("target/test/ks");
# This module simply prints to the default filehandle.
select($fh);

NCM::Component::ks::kspostreboot_header($cfg);

# some diagnostic messages can get caught up in the result via print
my $text = "$fh";
$text =~ s/^\[VERB.*\n//gm;

my $header = <<'EOHEADER';
#!/bin/bash
# Script to run at the first reboot. It installs the base Quattor RPMs
# and runs the components needed to get the system correctly
# configured.

hostname x.y

# Function to be called if there is an error in this phase.
# It sends an e-mail to root@example.com alerting about the failure.
fail() {
    echo "Quattor installation on x.y failed: \$1"
    subject="[\`date +'%x %R %z'\`] Quattor installation on x.y failed: \$1"
    if [ -x /usr/bin/mailx ]; then
        env MAILRC=/dev/null from=root@x.y  smtp=smtp.example.com mailx -s "\$subject" root@example.com <<End_of_mailx

\`cat /root/ks-post-reboot.log\`
------------------------------------------------------------
\`ls -tr /var/log/ncm 2>/dev/null|xargs tail /var/log/spma.log\`

End_of_mailx
    else
        sendmail -t <<End_of_sendmail
From: root@x.y
To: root@example.com
Subject: \$subject

\`cat /root/ks-post-reboot.log\`
------------------------------------------------------------
\`ls -tr /var/log/ncm 2>/dev/null|xargs tail /var/log/spma.log\`

.
End_of_sendmail
    fi
    # Drain remote logger (0 if not relevant)
    sleep \$drainsleep
    exit 1
}

# Function to be called if the installation succeeds.  It can send an
# e-mail to root@example.com alerting about the installation success.
success() {
    echo "Quattor installation on x.y succeeded"
    # No mail on success
    return

    subject="[\`date +'%x %R %z'\`] Quattor installation on x.y succeeded"
    if [ -x /usr/bin/mailx ]; then
        env MAILRC=/dev/null from=root@x.y  smtp=smtp.example.com mailx -s "\$subject" root@example.com <<End_of_mailx

Node x.y successfully installed.

End_of_mailx
    else
        sendmail -t <<End_of_sendmail
From: root@x.y
To: root@example.com
Subject: \$subject

Node x.y successfully installed.
.
End_of_sendmail
    fi
    # Drain remote logger (0 if not relevant)
    sleep \$drainsleep
}

# Wait for functional network up by testing DNS lookup via nslookup.
wait_for_network () {
    # Wait up to 2 minutes until the network comes up
    i=0
    while ! nslookup \$1 > /dev/null
    do
        sleep 1
        let i=\$i+1
        if [ \$i -gt 120 ]
        then
            fail "Network does not come up (nslookup \$1)"
        fi
    done
}

# Ensure that the log file doesn't exist.
[ -e /root/ks-post-reboot.log ] && \
    fail "Last installation went wrong. Aborting. See logfile /root/ks-post-reboot.log."

exec >/root/ks-post-reboot.log 2>&1
console='/dev/console'
[ -c /dev/pts/0 ] && console='/dev/pts/0'
# Make sure messages show up on the serial console
tail -f /root/ks-post-reboot.log > \$console &
drainsleep=0

echo 'Begin of ks-post-reboot'
set -x

wait_for_network x.y

EOHEADER

if ($text ne $header) {
    diag "diff header ", diff (\$text, \$header);
};
is($text, $header, "ks postreboot header generated (see diff header)");

# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing();
