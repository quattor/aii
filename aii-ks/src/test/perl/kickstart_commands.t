use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_commands);
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<kscommands> method.

=cut

$CAF::Object::NoAction = 1;

my $fh = CAF::FileWriter->new("target/test/ks");
# This module simply prints to the default filehandle.
select($fh);

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kickstart_commands');

NCM::Component::ks::kscommands($cfg);
# test enable and disable
# check chkconfig --del and services list
like($fh, qr{^\s*services\s*--disabled=disable1,DISABLE2\s*--enabled=enable1,ENABLE2}m, "--dis/enable services present");


done_testing();
