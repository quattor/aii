use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_base_config pxelinux_grub2 pxelinux_grub_glob);
use NCM::Component::PXELINUX::constants qw(:pxe_variants :pxe_constants);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;
use Readonly;


=pod

=head1 SYNOPSIS

Tests for the C<_write_grub2_config> method.

=cut

Readonly my $NBPDIR_GRUB2_VALUE => '/grub/config_files';
Readonly my $GRUB2_EFI_KERNEL_ROOT_VALUE => '/quat/or';
Readonly my $TEST_EFI_LINUX_CMD => GRUB2_EFI_LINUX_CMD_DEFAULT;
my $test_efi_initrd_cmd = $TEST_EFI_LINUX_CMD;
$test_efi_initrd_cmd =~ s/linux/initrd/;

$CAF::Object::NoAction = 1;

our $this_app = $main::this_app;


sub check_config {
    my ($comp, $cfg, $kernel_root, $test_msg) = @_;

    $comp->_write_grub2_config($cfg);

    # Retrieve config file name matching the configuration
    my $fp = $comp->_file_path($cfg, PXE_VARIANT_GRUB2);

    # Check config file contents
    my $fh = get_file($fp);
    my $hostname = hostname();
    my $prefix = $kernel_root ? "$kernel_root/" : "";
    like($fh, qr{^set default=0$}m, "default kernel ($test_msg)");
    like($fh, qr{^set timeout=\d+$}m, "Grub2 menu timeout ($test_msg)");
    like($fh, qr(^menuentry\s"Install\s[\w\-\s()\[\]]+"\s\{$)m, "Grub2 menu entry ($test_msg)");
    like($fh, qr{^\s{4}set root=\(pxe\)$}m, "Grub2 root ($test_msg)");
    like($fh, qr{^\s{4}$TEST_EFI_LINUX_CMD ${prefix}mykernel}m, "Kernel loading ($test_msg)");
    like($fh, qr{^\s{4}$test_efi_initrd_cmd ${prefix}path/to/initrd$}m, "initrd loading ($test_msg)");
    like($fh, qr(^})m, "end of menu entry ($test_msg)");
}


my $comp = NCM::Component::pxelinux->new('grub2_config');
my $cfg = get_config_for_profile('pxelinux_base_config');

# Define a few AII options related to Grub2 support
# Normally done by aii-shellfe
$this_app->{CONFIG}->define(GRUB2_EFI_LINUX_CMD);
$this_app->{CONFIG}->set(GRUB2_EFI_LINUX_CMD, $TEST_EFI_LINUX_CMD);
$this_app->{CONFIG}->define(GRUB2_EFI_INITRD_CMD);
$this_app->{CONFIG}->set(GRUB2_EFI_INITRD_CMD, $test_efi_initrd_cmd);
$this_app->{CONFIG}->define(NBPDIR_GRUB2);
$this_app->{CONFIG}->set(NBPDIR_GRUB2, $NBPDIR_GRUB2_VALUE);

check_config($comp, $cfg, '', 'No GRUB2_EFI_KERNEL_ROOT');

$this_app->{CONFIG}->define(GRUB2_EFI_KERNEL_ROOT);
$this_app->{CONFIG}->set(GRUB2_EFI_KERNEL_ROOT, $GRUB2_EFI_KERNEL_ROOT_VALUE);
check_config($comp, $cfg, $GRUB2_EFI_KERNEL_ROOT_VALUE, 'No GRUB2_EFI_KERNEL_ROOT');

$cfg = get_config_for_profile('pxelinux_grub2');

$this_app->{CONFIG}->set(GRUB2_EFI_KERNEL_ROOT, "/foo/bar");
check_config($comp, $cfg, qr{\(http,myhost\.example\)}, 'Profile ignores GRUB2_EFI_KERNEL_ROOT');

$cfg = get_config_for_profile('pxelinux_grub_glob');

$this_app->{CONFIG}->set(GRUB2_EFI_KERNEL_ROOT, "/foooo/baarr");
check_config($comp, $cfg, qr{\(http,abc.def\)},
             'Profile ignores GRUB2_EFI_KERNEL_ROOT, and replaces protocol');

done_testing();
