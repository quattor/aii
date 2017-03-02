use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_ks_el7_static_ip);
use NCM::Component::PXELINUX::constants qw(:pxe_variants :pxe_constants);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;
use Readonly;

=pod

=head1 SYNOPSIS

Tests for the C<_write_xxx_config> methods with a static IP and logging parameters (EL7 config)

=cut

Readonly my $TEST_EFI_LINUX_CMD => GRUB2_EFI_LINUX_CMD_DEFAULT;
my $test_efi_initrd_cmd = $TEST_EFI_LINUX_CMD;
$test_efi_initrd_cmd =~ s/linux/initrd/;

# Must be in the same order as variants in @PXE_VARIANTS
Readonly my @KERNEL_PARAMS_CMDS => ('append', GRUB2_EFI_LINUX_CMD_DEFAULT);
Readonly my @PXE_VARIANT_METHODS => ('_write_pxelinux_config', '_write_grub2_config');
Readonly my @VARIANT_NAMES => ('PXELINUX', 'Grub2');

# List of configurations to test (must be added as Test::Quattor parameters)
Readonly my @TEST_PROFILES => ('pxelinux_ks_el7_static_ip');

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
        
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\sinst.syslog=logserver:514\sinst.loglevel=debug(\s|$)}m,
             "append line logging (profile=$profile, variant=$variant_name)");
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\sinst.ks=http://server/ks\sbootdev=eth0(\s|$)}m,
             "append line ks and bootdev (profile=$profile, variant=$variant_name)");

        # both nameservers
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\snameserver=nm1(\s|$)}m,
             "append nameserver 1 (profile=$profile, variant=$variant_name)");
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\snameserver=nm2(\s|$)}m,
             "append nameserver 2 (profile=$profile, variant=$variant_name)");

        # both ifnames
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\sifname=eth0:00:11:22:33:44:55(\s|$)}m,
             "append ifname for 1st nic (profile=$profile, variant=$variant_name)");
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\sifname=eth1:00:11:22:33:44:66(\s|$)}m,
             "append ifname for 2nd nic (profile=$profile, variant=$variant_name)");

        # static ip
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\sip=133\.2\.85\.234::133\.2\.85\.1:255\.255\.255\.0:x.y:eth0:none(\s|$)}m,
             "append static ip for bootdev (profile=$profile, variant=$variant_name)");

        # enable sshd
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\sinst.sshd(\s|$)}m,
             "append enable sshd (profile=$profile, variant=$variant_name)");

        # enable cmdline
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\sinst.cmdline(\s|$)}m,
             "append enable cmdline (profile=$profile, variant=$variant_name)");

        # updates
        like($fh,
             qr{^\s{4}$kernel_params_cmd\s.*?\sinst.updates=http://somewhere/somthing/updates.img(\s|$)}m,
             "append updates (profile=$profile, variant=$variant_name)");

    };
};

done_testing();
