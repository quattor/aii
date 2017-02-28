use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_no_append_block);
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

my $comp = NCM::Component::pxelinux->new('pxelinux_no_append');
my $cfg = get_config_for_profile('pxelinux_no_append_block');

$comp->_write_pxelinux_config($cfg);

my $fh = get_file($fp);

like($fh, qr{^default\sInstall\sScientific\sLinux\s6x\s\(x86_64\)}m, 'default kernel');
like($fh, qr{^\s{4}label\sScientific\sLinux\s6x\s\(x86_64\)}m, 'label default kernel');
like($fh, qr{^\s{4}kernel\smykernel}m, 'kernel mykernel');

unlike($fh, qr{^\s*append}m, 'no append line');


done_testing();
