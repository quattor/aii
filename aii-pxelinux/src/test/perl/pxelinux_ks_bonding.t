use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_ks_bonding);
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
my $cfg = get_config_for_profile('pxelinux_ks_bonding');

NCM::Component::pxelinux::pxeprint($cfg);

my $fh = get_file($fp);

# bonding opts
like($fh, qr{^\s{4}append\s.*?\sbond=bond0:eth0,eth1:(opt1=val1,opt2=val2|opt2=val2,opt1=val1)(\s|$)}m, 'append bond');

# static ip settings from bond0, also bond0 is bootdev
like($fh, qr{^\s{4}append\s.*?\sip=1.2.3.0::1.2.3.4:255.255.255.0:x.y:bond0:none(\s|$)}m, 'append static ip for bootdev bond0');

# kickstart file should be fetched via ksdevice bond0
# this is EL7, the EL6 test should be ksdevice=bond0
like($fh, qr{^\s{4}append\s.*?\sbootdev=bond0(\s|$)}m, 'append set ksdevice/bootdev to bond0');


done_testing();
