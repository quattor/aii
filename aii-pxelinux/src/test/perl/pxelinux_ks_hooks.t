use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_ks_hooks);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;
use Data::Dumper;
use constant RESCUE_HOOK_PATH => '/system/aii/hooks/rescue';
use constant INSTALL_HOOK_PATH => '/system/aii/hooks/install';
use constant REMOVE_HOOK_PATH => '/system/aii/hooks/remove';
use constant CONFIGURE_HOOK_PATH => '/system/aii/hooks/configure';
use constant BOOT_HOOK_PATH => '/system/aii/hooks/boot';
use constant FIRMWARE_HOOK_PATH => '/system/aii/hooks/firmware';
use constant LIVECD_HOOK_PATH => '/system/aii/hooks/livecd';

=pod

=head1 SYNOPSIS

Tests for the configure hook

=cut

$CAF::Object::NoAction = 1;


# mock filepath, it has this_app->option
my $ksuserhooks;
my $fp = "target/test/pxelinux";
my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');
$mockpxe->mock('filepath', $fp);

my $ks = NCM::Component::pxelinux->new();
my $cfg = get_config_for_profile('pxelinux_ks_hooks');

NCM::Component::pxelinux::pxeprint($cfg);
$ksuserhooks = NCM::Component::pxelinux::ksuserhooks($cfg, CONFIGURE_HOOK_PATH);
is($ksuserhooks, undef, 'Configure hook');
$ksuserhooks = NCM::Component::pxelinux::ksuserhooks($cfg, INSTALL_HOOK_PATH);
is($ksuserhooks, undef, 'Install hook');
$ksuserhooks = NCM::Component::pxelinux::ksuserhooks($cfg, REMOVE_HOOK_PATH);
is($ksuserhooks, undef, 'Remove hook');
$ksuserhooks = NCM::Component::pxelinux::ksuserhooks($cfg, RESCUE_HOOK_PATH);
is($ksuserhooks, undef, 'Rescue hook');
$ksuserhooks = NCM::Component::pxelinux::ksuserhooks($cfg, BOOT_HOOK_PATH);
is($ksuserhooks, undef, 'Boot hook');
$ksuserhooks = NCM::Component::pxelinux::ksuserhooks($cfg, FIRMWARE_HOOK_PATH);
is($ksuserhooks, undef, 'Firmware hook');
$ksuserhooks = NCM::Component::pxelinux::ksuserhooks($cfg, LIVECD_HOOK_PATH);
is($ksuserhooks, undef, 'Livecd hook');

done_testing();
