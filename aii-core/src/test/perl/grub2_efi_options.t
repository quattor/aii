use strict;
use warnings;
use CAF::Application;
use Test::Quattor;
use Test::More;
use NCM::Component::PXELINUX::constants qw(:pxe_constants);
use AII::Shellfe;
use Readonly;
use File::Basename qw(basename);

my $logfile_name = basename(__FILE__);
$logfile_name =~ s/\.t$//;

Readonly my $AII_CONFIG_EMPTY => 'src/test/resources/aii-empty.conf';
Readonly my $AII_CONFIG_NBPDIR => 'src/test/resources/aii-nbpdir.conf';
Readonly my $AII_CONFIG_GRUB2_ONLY => 'src/test/resources/aii-grub2_only.conf';
Readonly my $AII_CONFIG_PXELINUX_GRUB2 => 'src/test/resources/aii-pxelinux_grub2.conf';
Readonly my $AII_CONFIG_PXELINUX_ONLY => 'src/test/resources/aii-pxelinux_only.conf';
Readonly my $AII_LOG_FILE => "target/test/$logfile_name.log";
Readonly::Array my @SHELLFE_DEFAULT_OPTIONS => ('--logfile', $AII_LOG_FILE);

sub check_option_values {
    my ($config_file, $test_name, $nbdir_grub2_expected, $grub2_efi_linux_cmd_expected, $grub2_efi_kernel_root_expected) = @_;
 
    my @opts = (@SHELLFE_DEFAULT_OPTIONS, '--cfgfile', $config_file);
    our $this_app = AII::Shellfe->new ($0, @opts);
 
    is($this_app->option("nbpdir_grub2"),
                         $nbdir_grub2_expected,
                         "expected default value for option nbpdir_grub2 ($test_name)");
    is($this_app->option("grub2_efi_linux_cmd"),
                         $grub2_efi_linux_cmd_expected,
                         "expected default value for option grub2_efi_linux_cmd ($test_name)");
    if ( defined($grub2_efi_linux_cmd_expected) ) {
        # Value derived from $grub2_efi_linux_cmd_expected (copied from Shellfe.pm)
        my $grub2_efi_initrd_cmd_expected = $grub2_efi_linux_cmd_expected;
        $grub2_efi_initrd_cmd_expected =~ s/linux/initrd/;
        # If both are identical, it means that $grub2_efi_linux_cmd_expected is not a valid kernel (linux) command
        isnt($grub2_efi_initrd_cmd_expected, $grub2_efi_linux_cmd_expected, "kernel and initrd commands are different");
        is($this_app->option("grub2_efi_initrd_cmd"),
                             $grub2_efi_initrd_cmd_expected,
                             "expected default value for option grub2_efi_initrd_cmd ($test_name)");
    }
    is($this_app->option("grub2_efi_kernel_root"),
                         $grub2_efi_kernel_root_expected,
                         "expected default value for option grub2_efi_kernel_root ($test_name)");

}

# Be sure that the directory for logs exists
mkdir 'target/test';

check_option_values ($AII_CONFIG_EMPTY,
                     'empty config file',
                     OSINSTALL_DEF_ROOT_PATH.OSINSTALL_DEF_GRUB2_DIR,
                     GRUB2_EFI_LINUX_CMD_DEFAULT,
                     '/nbp');
check_option_values ($AII_CONFIG_NBPDIR,
                     'nbpdir defined',
                     '/tftp/boot/quattor/grub-efi',
                     GRUB2_EFI_LINUX_CMD_DEFAULT,
                     '/boot/quattor');
check_option_values ($AII_CONFIG_GRUB2_ONLY,
                     'Grub2 only',
                     OSINSTALL_DEF_ROOT_PATH.OSINSTALL_DEF_GRUB2_DIR,
                     GRUB2_EFI_LINUX_CMD_DEFAULT,
                     '/nbp');
check_option_values ($AII_CONFIG_PXELINUX_GRUB2,
                     'PXELINUX + Grub2',
                     '/tftp/boot/quattor/grub.config',
                     'linux',
                     '/tftp/boot/kernels');
check_option_values ($AII_CONFIG_PXELINUX_ONLY,
                     'PXELINUX only',
                     undef,
                     GRUB2_EFI_LINUX_CMD_DEFAULT,
                     undef);

done_testing();
