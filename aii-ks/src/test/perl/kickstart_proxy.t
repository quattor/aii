use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_proxy kickstart_noproxy);
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<proxy> method.

=cut

$CAF::Object::NoAction = 1;


my $cfg = get_config_for_profile('kickstart_proxy');

is_deeply([NCM::Component::ks::proxy($cfg)],
          [qw(proxy.server1 1234 forward)],
          "Return expected proxy config");

$cfg = get_config_for_profile('kickstart_noproxy');

is_deeply([NCM::Component::ks::proxy($cfg)],
          [undef,undef,undef],
          "undef/disabled proxy config");

done_testing();
