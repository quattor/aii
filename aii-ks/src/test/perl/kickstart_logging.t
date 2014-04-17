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
like($fh, qr{^%packages\s--ignoremissing\s--resolvedeps\n^package\n^package2\n^nc\n^initscripts\n^EENNDD\n}m, 'installtype present');

done_testing();
