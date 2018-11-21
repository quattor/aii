use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_proxy kickstart_noproxy);
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;

=pod

=head1 SYNOPSIS

Tests for the C<proxy> method.

=cut

$CAF::Object::NoAction = 1;

BEGIN {
    no warnings qw(redefine);
    *Sys::Hostname::hostname = sub { return 'proxy.server2' };
}

use NCM::Component::ks;

my $cfg = get_config_for_profile('kickstart_proxy');

is_deeply([NCM::Component::ks::proxy($cfg)],
          [qw(proxy.server2 1234 forward)],
          "Return expected proxy config");

$cfg = get_config_for_profile('kickstart_noproxy');

is_deeply([NCM::Component::ks::proxy($cfg)],
          [undef,undef,undef],
          "undef/disabled proxy config");

done_testing();
