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

Tests for the C<filepath> method.

=cut

$CAF::Object::NoAction = 1;

Readonly my $NBPDIR_PXELINUX_VALUE => '/pxe/linux/conf.files';
Readonly my $NBPDIR_GRUB2_VALUE => '/grub/config_files';

# Define a few required AII options
# Normally done by aii-shellfe
our $this_app = $main::this_app;
$this_app->{CONFIG}->define(NBPDIR_PXELINUX);
$this_app->{CONFIG}->set(NBPDIR_PXELINUX, $NBPDIR_PXELINUX_VALUE);
$this_app->{CONFIG}->define(NBPDIR_GRUB2);
$this_app->{CONFIG}->set(NBPDIR_GRUB2, $NBPDIR_GRUB2_VALUE);

my $comp = NCM::Component::pxelinux->new('grub2_config');
my $cfg = get_config_for_profile('pxelinux_base_config');

my $pxe_file_path;

$pxe_file_path = NCM::Component::pxelinux::filepath($cfg, PXE_VARIANT_PXELINUX);
is($pxe_file_path, "$NBPDIR_PXELINUX_VALUE/x.y.cfg", "PXE config file path ok for PXELINUX");

$pxe_file_path = NCM::Component::pxelinux::filepath($cfg, PXE_VARIANT_GRUB2);
is($pxe_file_path, "$NBPDIR_GRUB2_VALUE/x.y.cfg", "PXE config file path ok for Grub2");


done_testing();
