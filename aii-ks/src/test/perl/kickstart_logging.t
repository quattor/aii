use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_logging);
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<kscommands> method with emphasis on logging.

=cut

$CAF::Object::NoAction = 1;

my $fh = CAF::FileWriter->new("target/test/ks");
# This module simply prints to the default filehandle.
select($fh);

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kickstart_logging');

NCM::Component::ks::kscommands($cfg);

like($fh, qr{^logging\s--host=logserver\s--port=514\s--level=debug}m, 'logging present');

# netcat enabled, add nc and initscripts to packages that are required in %post and postreboot
like($fh, qr{^%packages\s--ignoremissing\s--resolvedeps\n^package\n^package2\n^bind-utils\ninitscripts\n^nc\n}m, 'installtype present');

# logaction tests
my $logaction = NCM::Component::ks::log_action($cfg, 'mylogfile', 1);
like($logaction, qr{^exec\s>mylogfile\s2>&1}, 'start with exec redirection'); # no multiline search!
like($logaction, qr{^tail\s-f\smylogfile\s>\s/dev/console\s&}m, 'console logging enabled');

like($logaction, qr{^wait_for_network\slogserver}m, 'Insert sleep to make sure network is up');
like($logaction, qr{^\(tail\s-f\smylogfile.*?usleep.*?\snc\s-u\slogserver\s514\)\s&$}m, 'netcat udp logsending');
like($logaction, qr{^sleep\s\d+$}m, 'sleep inserted to allow start');

# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing();
