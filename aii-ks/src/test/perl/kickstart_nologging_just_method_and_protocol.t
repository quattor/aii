use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_nologging_just_method_and_protocol);
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
my $cfg = get_config_for_profile('kickstart_nologging_just_method_and_protocol');

NCM::Component::ks::kscommands($cfg);

unlike($fh, qr{^logging}m, 'no logging present');

# logaction tests
my $logaction = NCM::Component::ks::log_action($cfg, 'mylogfile', 1);
# mandatory
like($logaction, qr{^exec\s>mylogfile\s2>&1}, 'start with exec redirection'); # no multiline search!

# hmm, first test might be too specific in case of subtle changes
unlike($logaction, qr{^tail\s-f\smylogfile\s>\s/dev/console\s&}m, 'no console logging enabled');
unlike($logaction, qr{/dev/console}, 'no /dev/console at all');

unlike($logaction, qr{^\(tail\s-f\smylogfile.*?usleep.*\)\s&$}m, 'no logsending');
unlike($logaction, qr{usleep}, 'no usleep at all');

# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing();
