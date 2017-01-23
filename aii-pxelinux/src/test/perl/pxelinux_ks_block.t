use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_ks_block);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;

=pod

=head1 SYNOPSIS

Tests for the C<write_pxelinux_config> method.

=cut

$CAF::Object::NoAction = 1;

# mock filepath, it has this_app->option
my $fp = "target/test/pxelinux";
my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');
$mockpxe->mock('filepath', $fp);

my $ks = NCM::Component::pxelinux->new('pxelinux_ks');
my $cfg = get_config_for_profile('pxelinux_ks_block');

NCM::Component::pxelinux::write_pxelinux_config($cfg);

my $fh = get_file($fp);
my $hostname = hostname();

like($fh, qr{^default\sInstall\sScientific\sLinux\s6x\s\(x86_64\)}m, 'default kernel');
like($fh, qr{^\s{4}label\sScientific\sLinux\s6x\s\(x86_64\)}m, 'label default kernel');
like($fh, qr{^\s{4}kernel\smykernel}m, 'kernel mykernel');
like($fh, qr{^\s{4}append\sramdisk=32768\sinitrd=path/to/initrd(\s|$)}m, 'append ramdisk and initrd');
like($fh, qr{^\s{4}append.*?\sks=http://server/ks(\s|$)}m, 'append ks url');
like($fh, qr{^\s{4}append.*?\sksdevice=eth0(\s|$)}m, 'append ksdevice');
like($fh, qr{^\s{4}append.*?\supdates=http://somewhere/somthing/updates.img(\s|$)}m, 'append ksdevice');
like($fh, qr{^\s{4}append.*?\sinst.stage2=http://$hostname/stage2.img}m, 'hostname substitution in append');

done_testing();
