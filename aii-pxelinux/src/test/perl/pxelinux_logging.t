use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_logging);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<pxeprint> method.

=cut

$CAF::Object::NoAction = 1;

# mock filepath, it has this_app->option
my $fp = "target/test/pxelinux";
my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');
$mockpxe->mock('filepath', $fp);

my $ks = NCM::Component::pxelinux->new('pxelinux');
my $cfg = get_config_for_profile('pxelinux_logging');

NCM::Component::pxelinux::pxeprint($cfg);

my $fh = get_file($fp);

like($fh, qr{^\s{4}append\s.*?\ssyslog=logserver:514\sloglevel=debug(\s|$)}m, 'append line');


done_testing();
