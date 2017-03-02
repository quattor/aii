use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_base_config);
use NCM::Component::PXELINUX::constants qw(:all);
use NCM::Component::pxelinux;
use CAF::FileReader;
use CAF::Object;
use Sys::Hostname;
use Readonly;


=pod

=head1 SYNOPSIS

Tests for the C<_pxelink> method.

=cut

our $this_app = $main::this_app;

sub pxelink_test {
    my ($comp, $cfg, $command, $pxe_variant, $pxe_variant_name) = @_;
    unless ( defined($command) ) {
        $command = "";
    }

    my $pxelink_status = $comp->_pxelink($cfg, $command, $pxe_variant);
    ok($pxelink_status, "pxelink ok for $pxe_variant_name (command=$command)");
}

sub mocked_symlink ($$) {
    my ($target, $link) = @_;
    $this_app->info("Would create symlink $link with target $target");
}

# Mock symlink
my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');
$mockpxe->mock('symlink', \&mocked_symlink);

Readonly my $NBPDIR_PXELINUX_VALUE => '/pxe/linux/conf.files';
Readonly my $NBPDIR_GRUB2_VALUE => '/grub/config_files';
# Keep in the same order as variants in @PXE_VARIANTS
Readonly my @PXE_VARIANT_NAMES => ('PXELINUX', 'Grub2');
Readonly my @PXE_VARIANT_NBPDIR => ($NBPDIR_PXELINUX_VALUE, $NBPDIR_GRUB2_VALUE);

# Define a few required AII options
# Normally done by aii-shellfe
$this_app->{CONFIG}->define(NBPDIR_PXELINUX);
$this_app->{CONFIG}->set(NBPDIR_PXELINUX, $NBPDIR_PXELINUX_VALUE);
$this_app->{CONFIG}->define(NBPDIR_GRUB2);
$this_app->{CONFIG}->set(NBPDIR_GRUB2, $NBPDIR_GRUB2_VALUE);
$this_app->{CONFIG}->define(LOCALBOOT);
$this_app->{CONFIG}->set(LOCALBOOT, LOCAL_BOOT_CONFIG_FILE);

my $comp = NCM::Component::pxelinux->new('grub2_config');
my $cfg = get_config_for_profile('pxelinux_base_config');
my $pxe_config = $cfg->getElement('/system/aii/nbp/pxelinux')->getTree();

for my $variant_constant (@PXE_VARIANTS) {
    my $variant = __PACKAGE__->$variant_constant;

    # Create expected config file for rescue, firmware and livecd
    for my $action ('firmware', 'livecd', 'rescue') {
        my $file = "$PXE_VARIANT_NBPDIR[$variant]/$pxe_config->{$action}";
        set_file_contents($file, '');
        my $fh = CAF::FileReader->new($file);
        ok(defined($fh), "$file created");
    };

    # Do the test
    for my $action_constant (@PXE_COMMANDS) {
        my $action = __PACKAGE__->$action_constant; 
        pxelink_test($comp, $cfg, $action, $variant, $PXE_VARIANT_NAMES[$variant]);
    };
};


done_testing();
