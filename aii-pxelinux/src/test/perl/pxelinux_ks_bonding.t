use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_ks_bonding pxelinux_ks_bonding_bridge);
use NCM::Component::PXELINUX::constants qw(:pxe_variants :pxe_constants);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;
use Readonly;

=pod

=head1 SYNOPSIS

Tests for the C<_write_xxx_config> methods with bonding paramaters in KS options.

=cut

Readonly my $TEST_EFI_LINUX_CMD => GRUB2_EFI_LINUX_CMD_DEFAULT;
my $test_efi_initrd_cmd = $TEST_EFI_LINUX_CMD;
$test_efi_initrd_cmd =~ s/linux/initrd/;

# Must be in the same order as variants in @PXE_VARIANTS
Readonly my @KERNEL_PARAMS_CMDS => ('append', GRUB2_EFI_LINUX_CMD_DEFAULT);
Readonly my @PXE_VARIANT_METHODS => ('_write_pxelinux_config', '_write_grub2_config');
Readonly my @VARIANT_NAMES => ('PXELINUX', 'Grub2');

# List of configurations to test (must be added as Test::Quattor parameters)
Readonly my @TEST_PROFILES => ('pxelinux_ks_bonding', 'pxelinux_ks_bonding_bridge');

our $this_app = $main::this_app;
$this_app->{CONFIG}->define(GRUB2_EFI_LINUX_CMD);
$this_app->{CONFIG}->set(GRUB2_EFI_LINUX_CMD, $TEST_EFI_LINUX_CMD);
$this_app->{CONFIG}->define(GRUB2_EFI_INITRD_CMD);
$this_app->{CONFIG}->set(GRUB2_EFI_INITRD_CMD, $test_efi_initrd_cmd);

# mock _filepath, it has this_app->option
my $fp = "target/test/pxelinux";
my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');
$mockpxe->mock('_filepath', $fp);

my $comp = NCM::Component::pxelinux->new('pxelinux_ks');

for my $profile (@TEST_PROFILES) {
    my $cfg = get_config_for_profile($profile);

    for my $variant_constant (@PXE_VARIANTS) {
        my $variant = __PACKAGE__->$variant_constant;
        my $variant_name = $VARIANT_NAMES[$variant];
        my $config_method = $PXE_VARIANT_METHODS[$variant];
        my $kernel_params_cmd = $KERNEL_PARAMS_CMDS[$variant];
    
        $comp->$config_method($cfg);
        my $fh = get_file($fp);
        
        # bonding opts
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\sbond=bond0:eth0,eth1:(opt1=val1,opt2=val2|opt2=val2,opt1=val1)(\s|$)}m,
             "append bond ksdevice (profile=$profile, variant=$variant_name)");
        
        # static ip settings from bond0, also bond0 is bootdev
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\sip=1\.2\.3\.0::133\.2\.85\.1:255\.255\.255\.0:x.y:bond0:none(\s|$)}m,
             "append static ip for bootdev bond0 ksdevice (profile=$profile, variant=$variant_name)");
        
        # kickstart file should be fetched via ksdevice bond0
        # this is EL7, the EL6 test should be ksdevice=bond0
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\sbootdev=bond0(\s|$)}m,
             "append set ksdevice/bootdev to bond0 ksdevice (profile=$profile, variant=$variant_name)");

    };
};

done_testing();
