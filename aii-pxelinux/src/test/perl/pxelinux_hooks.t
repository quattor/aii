use strict;
use warnings;
use CAF::Application;
use Test::Quattor qw(pxelinux_hooks);
use Test::More;
use NCM::Component::pxelinux;
use NCM::Component::ks qw(get_ks_userhook_args);
use Test::MockModule;
use subs 'NCM::Component::pxelinux::unlink';

BEGIN {
    our $this_app = CAF::Application->new('app');
    $this_app->{CONFIG}->define("nbpdir");
    $this_app->{CONFIG}->set("nbpdir", "1");
    $this_app->{CONFIG}->define("bootconfig");
    $this_app->{CONFIG}->set("bootconfig", "1");
}

my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');
foreach my $mm (qw(pxelink pxeprint unlink get_fqdn filepath link_filepath)) {
    $mockpxe->mock($mm, 0);
};

my @methods = qw(Configure Boot Livecd Firmware Rescue Install);
my @allmethods = qw(Unconfigure Status);
push(@allmethods, @methods); 

my $ks = NCM::Component::pxelinux->new('pxelinux_ks');
my $cfg = get_config_for_profile('pxelinux_hooks');

foreach my $method (@allmethods) {
    is($ks->$method($cfg), 1, "Method $method returns 1");
    my $hookargs = get_ks_userhook_args();
    isa_ok($hookargs->[0], 'EDG::WP4::CCM::Configuration', 
           "First arg passed to ksuserhooks in method $method is a CCM::Configuration instance");
    my $hp = '/system/aii/hooks/'.($method eq 'Unconfigure' ? 'remove' : lc($method));
    is($hookargs->[1], $hp, "Second arg passed to userhooks in method $method is path $hp");
};

done_testing();
