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

Tests for the C<_file_path> method.

=cut

# Must be in the same order as variants in @PXE_VARIANTS
Readonly my @VARIANT_NAMES => ('PXELINUX', 'Grub2');
Readonly my %NBPDIR_VALUES => (PXELINUX => '/pxe/linux/conf.files',
                               Grub2 => '/grub/config_files');

# Define a few required AII options
# Normally done by aii-shellfe
our $this_app = $main::this_app;
$this_app->{CONFIG}->define(NBPDIR_PXELINUX);
$this_app->{CONFIG}->set(NBPDIR_PXELINUX, $NBPDIR_VALUES{PXELINUX});
$this_app->{CONFIG}->define(NBPDIR_GRUB2);
$this_app->{CONFIG}->set(NBPDIR_GRUB2, $NBPDIR_VALUES{Grub2});

my $comp = NCM::Component::pxelinux->new('grub2_config');
my $cfg = get_config_for_profile('pxelinux_base_config');


for my $variant_constant (@PXE_VARIANTS) {
    my $variant = __PACKAGE__->$variant_constant;
    my $variant_name = $VARIANT_NAMES[$variant];

    my $pxe_file_path = $comp->_file_path($cfg, $variant);
    is($pxe_file_path, "$NBPDIR_VALUES{$variant_name}/x.y.cfg", "PXE config file path ok (variant=$variant_name)");
};


done_testing();
