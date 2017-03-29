use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_base_config pxelinux_no_rescue);
use NCM::Component::PXELINUX::constants qw(:all);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;
use Readonly;


=pod

=head1 SYNOPSIS

Tests for the C<_link_path> method.

=cut

Readonly my $RESCUE_CONFIG_FILE => 'my_rescue.cfg';
# Must be in the same order as variants in @PXE_VARIANTS
Readonly my @VARIANT_NAMES => ('PXELINUX', 'Grub2');
Readonly my %PXE_VARIANT_NBPDIR => (PXELINUX => '/pxe/linux/conf.files',
                                    Grub2 => '/grub/config_files');

# Define a few required AII options
# Normally done by aii-shellfe
our $this_app = $main::this_app;
$this_app->{CONFIG}->define(NBPDIR_PXELINUX);
$this_app->{CONFIG}->set(NBPDIR_PXELINUX, $PXE_VARIANT_NBPDIR{PXELINUX});
$this_app->{CONFIG}->define(NBPDIR_GRUB2);
$this_app->{CONFIG}->set(NBPDIR_GRUB2, $PXE_VARIANT_NBPDIR{Grub2});
$this_app->{CONFIG}->define(LOCALBOOT);
$this_app->{CONFIG}->set(LOCALBOOT, LOCAL_BOOT_CONFIG_FILE);
$this_app->{CONFIG}->define(RESCUEBOOT);
$this_app->{CONFIG}->set(RESCUEBOOT, $RESCUE_CONFIG_FILE);

my $comp = NCM::Component::pxelinux->new('grub2_config');
my $cfg = get_config_for_profile('pxelinux_base_config');
my $pxe_config = $cfg->getElement('/system/aii/nbp/pxelinux')->getTree();


# Main tests: check that link_path() works as expected when the configurion is correct

for my $variant_constant (@PXE_VARIANTS) {
    my $variant = __PACKAGE__->$variant_constant;
    my $variant_name = $VARIANT_NAMES[$variant];

    for my $action_constant (@PXE_COMMANDS) {
        my $action = __PACKAGE__->$action_constant;

        # link_path() must not be used with the following actions    
        next if !defined($action) || $action eq BOOT || $action eq INSTALL;

        my $pxe_link_path = $comp->_link_path($cfg, $action, $variant);
        is($pxe_link_path,
           "$PXE_VARIANT_NBPDIR{$variant_name}/$pxe_config->{$action}",
           "PXE config file path ok (action=$action_constant, variant=$variant_name)");
    };
};


# Ensure that link_path() fails with LIVECD and FIRMWARE if no PXE config file is defined
# For RESCUE, config option should be used.
# Not sensible to variant
$cfg = get_config_for_profile('pxelinux_no_rescue');
for my $action_constant (@PXE_COMMANDS) {
    my $action = __PACKAGE__->$action_constant;

    # link_path() must not be used with the following actions    
    next if !defined($action) || $action eq BOOT || $action eq INSTALL;

    my $pxe_link_path = $comp->_link_path($cfg, $action, PXE_VARIANT_PXELINUX);
    if ( $action eq RESCUE ) {
        my $dir = $PXE_VARIANT_NBPDIR{$VARIANT_NAMES[PXE_VARIANT_PXELINUX]};
        is ($pxe_link_path, "$dir/$RESCUE_CONFIG_FILE", "Option from configuration used for RESCUE");
    } else {
        ok (!$pxe_link_path, "link_path() failed: no PXE config file for action $action");
    }
};


# Ensure that link_path() fails if an unsupported action is passed
my $pxe_link_path = $comp->_link_path($cfg, 'unsupported', PXE_VARIANT_PXELINUX);
ok (!$pxe_link_path, "link_path() fails with an invalid action");


done_testing();
