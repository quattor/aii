use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_ks_el7_static_ip);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<_write_pxelinux_config> method.

=cut

$CAF::Object::NoAction = 1;

# mock _filepath, it has this_app->option
my $fp = "target/test/pxelinux";
my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');
$mockpxe->mock('_filepath', $fp);

my $comp = NCM::Component::pxelinux->new('pxelinux_ks');
my $cfg = get_config_for_profile('pxelinux_ks_el7_static_ip');

$comp->_write_pxelinux_config($cfg);

my $fh = get_file($fp);

like($fh, qr{^\s{4}append\s.*?\sinst.syslog=logserver:514\sinst.loglevel=debug(\s|$)}m, 'append line logging');
like($fh, qr{^\s{4}append\s.*?\sinst.ks=http://server/ks\sbootdev=eth0(\s|$)}m, 'append line ks and bootdev');
# both nameservers
like($fh, qr{^\s{4}append\s.*?\snameserver=nm1(\s|$)}m, 'append nameserver 1');
like($fh, qr{^\s{4}append\s.*?\snameserver=nm2(\s|$)}m, 'append nameserver 2');
# both ifnames
like($fh, qr{^\s{4}append\s.*?\sifname=eth0:00:11:22:33:44:55(\s|$)}m, 'append ifname for 1st nic');
like($fh, qr{^\s{4}append\s.*?\sifname=eth1:00:11:22:33:44:66(\s|$)}m, 'append ifname for 2nd nic');
# static ip
like($fh, qr{^\s{4}append\s.*?\sip=133\.2\.85\.234::133\.2\.85\.1:255\.255\.255\.0:x.y:eth0:none(\s|$)}m, 'append static ip for bootdev');
# enable sshd
like($fh, qr{^\s{4}append\s.*?\sinst.sshd(\s|$)}m, 'append enable sshd');
# enable cmdline
like($fh, qr{^\s{4}append\s.*?\sinst.cmdline(\s|$)}m, 'append enable cmdline');
# updates
like($fh, qr{^\s{4}append\s.*?\sinst.updates=http://somewhere/somthing/updates.img(\s|$)}m, 'append updates');


done_testing();
