use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_base_config);
use NCM::Component::PXELINUX::constants qw(:pxe_constants :pxe_commands);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;
use Readonly;


=pod

=head1 SYNOPSIS

Tests for the public methods.

This test only assess that internal methods to be called exists (they are all mocked in the test).
Testing of internal methods called by public methods are covered by other unit tests.
Errors (undefined methods) raise exceptions that cause the test to fail.

=cut

Readonly my $NBPDIR_PXELINUX_VALUE => '/pxe/linux/conf.files';
Readonly my $NBPDIR_GRUB2_VALUE => '/grub/config_files';

# Define a few required AII options
# Normally done by aii-shellfe
our $this_app = $main::this_app;
$this_app->{CONFIG}->define(NBPDIR_PXELINUX);
$this_app->{CONFIG}->set(NBPDIR_PXELINUX, $NBPDIR_PXELINUX_VALUE);
$this_app->{CONFIG}->define(NBPDIR_GRUB2);
$this_app->{CONFIG}->set(NBPDIR_GRUB2, $NBPDIR_GRUB2_VALUE);

my $comp = NCM::Component::pxelinux->new('grub2_config');
my $cfg = get_config_for_profile('pxelinux_base_config');

# Mock methods called by public methods
my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');
$mockpxe->mock('_pxelink', 1);
$mockpxe->mock('_write_grub2_config', 1);
$mockpxe->mock('_write_pxelinux_config', 1);
$mockpxe->mock('cleanup', 1);

for my $action (@PXE_COMMANDS, 'UNCONFIGURE', 'STATUS') {
    my $method = ucfirst(lc($action));
    my $status = $comp->Configure($cfg);
    ok($status, "$method can call the internal methods"); 
};

done_testing();
