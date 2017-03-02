use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_ks_block);
use NCM::Component::PXELINUX::constants qw(:pxe_variants :pxe_constants);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;
use Readonly;

=pod

=head1 SYNOPSIS

Tests for the C<_write_xxx_config> methods with the basic KS options.

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

# mock _filepath, it has this_app->option
my $fp = "target/test/pxelinux";
my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');
$mockpxe->mock('_filepath', $fp);

my $comp = NCM::Component::pxelinux->new('pxelinux_ks');
my $cfg = get_config_for_profile('pxelinux_ks_block');
my $hostname = hostname();

for my $variant_constant (@PXE_VARIANTS) {
    my $variant = __PACKAGE__->$variant_constant;
    my $variant_name = $VARIANT_NAMES[$variant];
    my $config_method = $PXE_VARIANT_METHODS[$variant];
    my $kernel_params_cmd = $KERNEL_PARAMS_CMDS[$variant];

    $comp->$config_method($cfg);
    my $fh = get_file($fp);
    
    like($fh, qr{^\s{4}$kernel_params_cmd.*?\sramdisk=32768(\s|$)}m, "append ramdisk (variant=$variant_name)");
    if ( $variant == PXE_VARIANT_PXELINUX ) {
        like($fh, qr{^\s{4}$kernel_params_cmd.*?\sinitrd=path/to/initrd(\s|$)}m, "append initrd (variant=$variant_name)");
    };
    like($fh, qr{^\s{4}$kernel_params_cmd.*?\sks=http://server/ks(\s|$)}m, "append ks url(variant=$variant_name)");
    like($fh, qr{^\s{4}$kernel_params_cmd.*?\sksdevice=eth0(\s|$)}m, "append ksdevice(variant=$variant_name)");
    like($fh, qr{^\s{4}$kernel_params_cmd.*?\supdates=http://somewhere/somthing/updates.img(\s|$)}m, "append ksdevice(variant=$variant_name)");
    like($fh, qr{^\s{4}$kernel_params_cmd.*?\sinst.stage2=http://$hostname/stage2.img}m, "hostname substitution in append(variant=$variant_name)");
};

done_testing();
