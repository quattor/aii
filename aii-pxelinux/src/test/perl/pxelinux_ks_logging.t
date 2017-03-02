use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_ks_logging pxelinux_ks_nologging_host);
use NCM::Component::PXELINUX::constants qw(:pxe_variants :pxe_constants);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;
use Readonly;

=pod

=head1 SYNOPSIS

Tests for the C<_write_xxx_config> methods (logging related parameters).

=cut

Readonly my $TEST_EFI_LINUX_CMD => GRUB2_EFI_LINUX_CMD_DEFAULT;
my $test_efi_initrd_cmd = $TEST_EFI_LINUX_CMD;
$test_efi_initrd_cmd =~ s/linux/initrd/;

# Must be in the same order as variants in @PXE_VARIANTS
Readonly my @KERNEL_PARAMS_CMDS => ('append', GRUB2_EFI_LINUX_CMD_DEFAULT);
Readonly my @PXE_VARIANT_METHODS => ('_write_pxelinux_config', '_write_grub2_config');
Readonly my @VARIANT_NAMES => ('PXELINUX', 'Grub2');

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


# Logging parameters specified

my $cfg = get_config_for_profile('pxelinux_ks_logging');
for my $variant_constant (@PXE_VARIANTS) {
    my $variant = __PACKAGE__->$variant_constant;
    my $variant_name = $VARIANT_NAMES[$variant];
    my $config_method = $PXE_VARIANT_METHODS[$variant];
    my $kernel_params_cmd = $KERNEL_PARAMS_CMDS[$variant];

    $comp->$config_method($cfg);
    my $fh = get_file($fp);
    
    like($fh, qr{^\s{4}$kernel_params_cmd\s.*?\ssyslog=logserver:514\sloglevel=debug(\s|$)}m, "append line (variant=$variant_name)");
};


# No logging host

$cfg = get_config_for_profile('pxelinux_ks_nologging_host');
for my $variant_constant (@PXE_VARIANTS) {
    my $variant = __PACKAGE__->$variant_constant;
    my $variant_name = $VARIANT_NAMES[$variant];
    my $config_method = $PXE_VARIANT_METHODS[$variant];
    my $kernel_params_cmd = $KERNEL_PARAMS_CMDS[$variant];

    $comp->$config_method($cfg);
    my $fh = get_file($fp);
    
    unlike($fh, qr{\ssyslog}, "no syslog config (variant=$variant_name)");
    unlike($fh, qr{\sloglevel}, "no loglevel config (variant=$variant_name)");
};

done_testing();
