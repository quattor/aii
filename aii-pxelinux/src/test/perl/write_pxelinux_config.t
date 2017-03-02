use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_base_config);
use NCM::Component::PXELINUX::constants qw(:pxe_variants :pxe_constants);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;
use Readonly;


=pod

=head1 SYNOPSIS

Tests for the C<_write_pxelinux_config> method.

=cut

Readonly my $NBPDIR_PXELINUX_VALUE => '/pxe/linux/conf.files';

$CAF::Object::NoAction = 1;

our $this_app = $main::this_app;

# Define a few AII options related to Grub2 support
# Normally done by aii-shellfe
$this_app->{CONFIG}->define(NBPDIR_PXELINUX);
$this_app->{CONFIG}->set(NBPDIR_PXELINUX, $NBPDIR_PXELINUX_VALUE);

my $comp = NCM::Component::pxelinux->new('grub2_config');
my $cfg = get_config_for_profile('pxelinux_base_config');

$comp->_write_pxelinux_config($cfg);

# Retrieve config file name matching the configuration
my $fp = $comp->_file_path($cfg, PXE_VARIANT_PXELINUX);

# Check config file contents
my $fh = get_file($fp);
my $hostname = hostname();
like($fh, qr(^default\sInstall\s[\w\-\s\(\)\[\]]+$)m, 'PXELINUX menu entry');
like($fh, qr{^\s{4}label\s[\w\-\s\(\)\[\]]+$}m, 'Label properly defined');
like($fh, qr{^\s{4}kernel\smykernel$}m, 'Kernel properly defined');
unlike($fh, qr{^\s*append}m, 'no append line');


done_testing();
