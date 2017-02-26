use strict;
use warnings;
use CAF::Application;
use Test::Quattor qw(pxelinux_hooks);
use Test::More;
use NCM::Component::PXELINUX::constants qw(:pxe_hooks);
use NCM::Component::ks qw(get_ks_userhook_args ksuserhooks);
use Test::MockModule;
use subs 'NCM::Component::pxelinux::unlink';

=pod

Unit test for arguments passed to ksuserhooks() (from aii-ks) for the
various actions supported by aii-pxelinux (calling sequence to ksuserhooks()
copied from pxelinux.pm).

=cut

BEGIN {
    our $this_app = CAF::Application->new('app');
    $this_app->{CONFIG}->define("nbpdir");
    $this_app->{CONFIG}->set("nbpdir", "1");
    $this_app->{CONFIG}->define("bootconfig");
    $this_app->{CONFIG}->set("bootconfig", "1");
}

my @methods = qw(Configure Boot Livecd Firmware Rescue Install Status Unconfigure);

my $cfg = get_config_for_profile('pxelinux_hooks');

foreach my $method (@methods) {
    my $hook_path;
    if ( $method eq 'Unconfigure' ) {
        $hook_path = REMOVE_HOOK_PATH;
    } elsif ( $method eq 'Status' ) {
        $hook_path = STATUS_HOOK_PATH;
    } else {
        $hook_path = HOOK_PATH . lc($method);
    }

    ksuserhooks($cfg, $hook_path);
    my $hookargs = get_ks_userhook_args();
    isa_ok($hookargs->[0], 'EDG::WP4::CCM::Configuration', 
           "First arg passed to ksuserhooks in method $method is a CCM::Configuration instance");
    my $hp = '/system/aii/hooks/'.($method eq 'Unconfigure' ? 'remove' : lc($method));
    is($hookargs->[1], $hp, "Second arg passed to userhooks in method $method is path $hp");
};

done_testing();
