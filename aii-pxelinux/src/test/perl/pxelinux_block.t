use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_block);
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
my $cfg = get_config_for_profile('pxelinux_block');

NCM::Component::pxelinux::pxeprint($cfg);

my $fh = get_file($fp);

like($fh, qr{^default\skernel\slabel}m, 'default kernel');
like($fh, qr{^\s{4}label\skernel\slabel}m, 'label default kernel');
like($fh, qr{^\s{4}kernel\smykernel}m, 'kernel mykernel');
like($fh, qr{^\s{4}append\sramdisk=32768\sinitrd=path/to/initrd\sks=http://server/ks\sksdevice=eth0}m, 'append line');


done_testing();
