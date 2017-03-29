use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_base_config);
use NCM::Component::PXELINUX::constants qw(:pxe_variants :pxe_constants);
use NCM::Component::pxelinux;
use CAF::FileReader;
use CAF::Object;
use Sys::Hostname;
use File::Basename qw(dirname);
use Readonly;


=pod

=head1 SYNOPSIS

Tests for the C<Unconfigure> method.

=cut

Readonly my $NBPDIR_GRUB2_VALUE => '/grub/config_files';
Readonly my $NBPDIR_PXELINUX_VALUE => '/pxelink/config_files';
Readonly my $FILE_INITIAL_CONTENTS => 'File has been configured';
Readonly my $SYMLINK_INITIAL_CONTENTS => 'Symlink has been defined';

our $this_app = $main::this_app;

my $fh;

# Define a few AII options related to Grub2 support
# Normally done by aii-shellfe
$this_app->{CONFIG}->define(NBPDIR_PXELINUX);
$this_app->{CONFIG}->set(NBPDIR_PXELINUX, $NBPDIR_PXELINUX_VALUE);
$this_app->{CONFIG}->define(NBPDIR_GRUB2);
$this_app->{CONFIG}->set(NBPDIR_GRUB2, $NBPDIR_GRUB2_VALUE);

my $comp = NCM::Component::pxelinux->new('unconfigure');
my $cfg = get_config_for_profile('pxelinux_base_config');
my $pxe_config = $cfg->getElement('/system/network/interfaces')->getTree();
my $ip = $pxe_config->{eth0}->{ip};

# Create a non emty file matching each PXE entries
foreach my $variant_constant (@PXE_VARIANTS) {
    my $variant = __PACKAGE__->$variant_constant;
    my $config_file = $comp->_file_path($cfg,$variant);
    my $pxe_symlink = dirname($config_file) . "/" . $comp->_hexip_filename($ip,$variant);
    set_file_contents($config_file, $FILE_INITIAL_CONTENTS);
    set_file_contents($pxe_symlink, $SYMLINK_INITIAL_CONTENTS);
    # Ensure that the file contents is really instanciated and reported by get_file()
    my $fh = CAF::FileReader->new($config_file);
    is("$fh", $FILE_INITIAL_CONTENTS, "PXE config file $config_file has expected contents (variant=$variant)");
    $fh = CAF::FileReader->new($pxe_symlink);
    is("$fh", $SYMLINK_INITIAL_CONTENTS, "PXE link $pxe_symlink has expected contents (variant=$variant)");
};

$comp->Unconfigure($cfg);
foreach my $variant_constant (@PXE_VARIANTS) {
    my $variant = __PACKAGE__->$variant_constant;
    my $config_file = $comp->_file_path($cfg,$variant);
    my $pxe_symlink = dirname($config_file) . "/" . $comp->_hexip_filename($ip,$variant);
    ok(!$comp->file_exists($config_file), "PXE config file $config_file removed (variant=$variant)");
    ok(!$comp->file_exists($pxe_symlink), "PXE link $pxe_symlink removed (variant=$variant)");
};

done_testing();
