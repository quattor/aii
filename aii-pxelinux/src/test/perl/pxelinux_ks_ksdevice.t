use strict;
use warnings;
use Test::More;
use Test::Quattor qw(
    pxelinux_ks_ksdevice_bootif 
    pxelinux_ks_ksdevice_mac 
    pxelinux_ks_ksdevice_link
    pxelinux_ks_ksdevice_systemd_scheme_1
    pxelinux_ks_ksdevice_systemd_scheme_2
    pxelinux_ks_ksdevice_systemd_scheme_3
    pxelinux_ks_ksdevice_systemd_scheme_4
);
use NCM::Component::PXELINUX::constants qw(:pxe_variants :pxe_constants);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;
use Readonly;

=pod

=head1 SYNOPSIS

Tests for the C<_write_xxx_config> methods with explicit ksdevice definition.

=cut

Readonly my $TEST_EFI_LINUX_CMD => GRUB2_EFI_LINUX_CMD_DEFAULT;
my $test_efi_initrd_cmd = $TEST_EFI_LINUX_CMD;
$test_efi_initrd_cmd =~ s/linux/initrd/;

# Must be in the same order as variants in @PXE_VARIANTS
Readonly my @KERNEL_PARAMS_CMDS => ('append', GRUB2_EFI_LINUX_CMD_DEFAULT);
Readonly my @PXE_VARIANT_METHODS => ('_write_pxelinux_config', '_write_grub2_config');
Readonly my @VARIANT_NAMES => ('PXELINUX', 'Grub2');

# List of configuration file prefix and suffix to test (must match Test::Quattor parameters)
Readonly my @TEST_PROFILE_PREFIXES => ('pxelinux_ks_ksdevice', 'pxelinux_ks_ksdevice_systemd');
Readonly my %TEST_PROFILE_SUFFIXES => (pxelinux_ks_ksdevice => ['bootif', 'mac', 'link'],
                                       pxelinux_ks_ksdevice_systemd => ['scheme_1', 'scheme_2', 'scheme_3', 'scheme_4']);
Readonly my %TEST_PROFILE_KSDEVICES => (pxelinux_ks_ksdevice => ['bootif', 'AA:BB:CC:DD:EE:FF', 'link'],
                                        pxelinux_ks_ksdevice_systemd => ['eno1', 'ens1', 'enp2s0', 'enx78e7d1ea46da']);

our $this_app = $main::this_app;
$this_app->{CONFIG}->define(GRUB2_EFI_LINUX_CMD);
$this_app->{CONFIG}->set(GRUB2_EFI_LINUX_CMD, $TEST_EFI_LINUX_CMD);
$this_app->{CONFIG}->define(GRUB2_EFI_INITRD_CMD);
$this_app->{CONFIG}->set(GRUB2_EFI_INITRD_CMD, $test_efi_initrd_cmd);

# mock _file_path, it has this_app->option
my $fp = "target/test/pxelinux";
my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');
$mockpxe->mock('_file_path', $fp);

my $comp = NCM::Component::pxelinux->new('pxelinux_ks');

for my $profile_prefix (@TEST_PROFILE_PREFIXES) {

    my $i=0;
    foreach my $suffix (@{$TEST_PROFILE_SUFFIXES{$profile_prefix}}) {
        my $profile = $profile_prefix . '_' . $suffix;
        my $cfg = get_config_for_profile($profile);
        my $ksdevice = $TEST_PROFILE_KSDEVICES{$profile_prefix}[$i];
        
        # Check that bonding is not defined for non standard devices (PXE variant agnostic)
        my $bond = $comp->_pxe_network_bonding($cfg, {}, $ksdevice);
        ok(! defined($bond),
            "Bonding for unsupported device '$ksdevice' returns undef (profile=$profile)");
            
        for my $variant_constant (@PXE_VARIANTS) {
            my $variant = __PACKAGE__->$variant_constant;
            my $variant_name = $VARIANT_NAMES[$variant];
            my $config_method = $PXE_VARIANT_METHODS[$variant];
            my $kernel_params_cmd = $KERNEL_PARAMS_CMDS[$variant];
    
            # Check ksdevice is correctly defined
            $comp->$config_method($cfg);
            my $fh = get_file($fp);
            like($fh,
                 qr{^\s{4}$kernel_params_cmd\s.*?\sksdevice=$ksdevice(\s|$)}m,
                 "ksdevice=$ksdevice (profile=$profile, variant=$variant_name)");
            if ( ($variant == PXE_VARIANT_PXELINUX) && ($suffix eq "bootif") ) {
                like($fh, qr{^\s{4}ipappend\s2$}m, "ipappend 2 added (profile=$profile, variant=$variant_name)");
            };
        }

        $i++; 
    };
};

done_testing();
