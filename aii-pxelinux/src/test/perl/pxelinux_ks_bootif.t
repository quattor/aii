use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_ks_bootif);
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

my $ks = NCM::Component::pxelinux->new('pxelinux_ks');
my $cfg = get_config_for_profile('pxelinux_ks_bootif');

NCM::Component::pxelinux::pxeprint($cfg);

my $fh = get_file($fp);

like($fh, qr{^\s{4}append\s.*?\sksdevice=bootif(\s|$)}m, 'ksdevice=bootif');
like($fh, qr{^\s{4}ipappend\s2$}m, 'ipappend 2');


done_testing();
