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

is_deeply(NCM::Component::ks::proxy($cfg),
          {host => 'proxy.server2', port => 1234, type => 'forward'},
          "Return expected proxy config");

$cfg = get_config_for_profile('kickstart_noproxy');

is_deeply(NCM::Component::ks::proxy($cfg), {}, "empty/disabled proxy config");

done_testing();
