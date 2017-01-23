#${PMpre} NCM::Component::PXELINUX::constants${PMpost}

=pod

This aii-pxelinux submodule only defines constants used by
pxelinux module and shared with others. It allows to share
the constant definitions without bringing all the aii-pxelinux
depencies.

=cut

use Readonly;
use Exporter qw(import);

# PXE commands supported
use constant CONFIGURE => undef;
use constant INSTALL => 'install';
use constant BOOT => 'boot';
use constant RESCUE => 'rescue';
use constant RESCUEBOOT => 'rescueconfig';
use constant FIRMWARE => 'firmware';
use constant LIVECD => 'livecd';

# Default paths and option values related to PXE configuration
use constant OSINSTALL_DEF_ROOT_PATH => '/osinstall/nbp';
use constant OSINSTALL_DEF_PXELINUX_DIR => '/pxelinux.cfg';
use constant OSINSTALL_DEF_GRUB2_DIR => '/grub-efi';
use constant LOCAL_BOOT_CONFIG_FILE => 'localboot.cfg';
use constant GRUB2_EFI_LINUX_CMD_DEFAULT => 'linuxefi';
use constant NBPDIR_VARIANT_DISABLED => 'none';

# Option names related to PXE configuration
use constant LOCALBOOT => 'bootconfig';
use constant NBPDIR_PXELINUX => 'nbpdir';
use constant NBPDIR_GRUB2 => 'nbpdir_grub2';
use constant GRUB2_EFI_KERNEL_ROOT => 'grub2_efi_kernel_root';
use constant GRUB2_EFI_LINUX_CMD => 'grub2_efi_linux_cmd';
use constant GRUB2_EFI_INITRD_CMD => 'grub2_efi_initrd_cmd';

# Hooks for NBP (PXE/UEFI) plug-in
use constant HOOK_PATH => '/system/aii/hooks/';
use constant REMOVE_HOOK_PATH => HOOK_PATH.'remove';
use constant STATUS_HOOK_PATH => HOOK_PATH.'status';

# Supported PXE variants 
use enum qw(PXE_VARIANT_PXELINUX PXE_VARIANT_GRUB2);

# To ease constant export/import by tests and other modules
# Some constants are use only by unit tests
Readonly my @PXE_VARIANTS => qw(
    PXE_VARIANT_PXELINUX
    PXE_VARIANT_GRUB2
);
Readonly my @PXE_CONSTANTS => qw(
    LOCALBOOT
    LOCAL_BOOT_CONFIG_FILE
    NBPDIR_VARIANT_DISABLED
    NBPDIR_PXELINUX
    NBPDIR_GRUB2
    GRUB2_EFI_KERNEL_ROOT
    GRUB2_EFI_INITRD_CMD
    GRUB2_EFI_LINUX_CMD
    GRUB2_EFI_LINUX_CMD_DEFAULT
    OSINSTALL_DEF_ROOT_PATH
    OSINSTALL_DEF_PXELINUX_DIR
    OSINSTALL_DEF_GRUB2_DIR
);
Readonly my @PXE_COMMANDS => qw(
    BOOT
    CONFIGURE
    FIRMWARE
    INSTALL
    LIVECD
    RESCUE
    RESCUEBOOT
);
Readonly my @PXE_HOOKS => qw(
    HOOK_PATH
    REMOVE_HOOK_PATH
    STATUS_HOOK_PATH
);
our @EXPORT_OK;
push @EXPORT_OK, @PXE_VARIANTS, @PXE_CONSTANTS, @PXE_COMMANDS, @PXE_HOOKS;
our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
    pxe_commands => \@PXE_COMMANDS,
    pxe_constants => \@PXE_CONSTANTS,
    pxe_hooks => \@PXE_HOOKS,
    pxe_variants => \@PXE_VARIANTS,
);

