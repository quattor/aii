use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_bonding_bridge kickstart_ovs_bridge);
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<kscommands> method.

=cut

$CAF::Object::NoAction = 1;

my $fh = CAF::FileWriter->new("target/test/ks");
# This module simply prints to the default filehandle.
select($fh);

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kickstart_bonding_bridge');

NCM::Component::ks::kscommands($cfg);

like($fh, qr{^network\s--bootproto=static\s--bondslaves=eth0,eth1\s--bondopts=(opt1=val1,opt2=val2|opt2=val2,opt1=val1)\s--device=bond0\s--hostname=x.y\s--nameserver=nm1\s--ip=1.2.3.0\s--netmask=255.255.255.0\s--gateway=1.2.3.4}m, 'kickstart bond and ip from from bridge');

$cfg = get_config_for_profile('kickstart_ovs_bridge');

NCM::Component::ks::kscommands($cfg);

like($fh, qr{^network\s--bootproto=static\s--device=eth0\s--hostname=x.y\s--nameserver=nm1\s--ip=1.2.3.0\s--netmask=255.255.255.0\s--gateway=1.2.3.4}m, 'kickstart ip from ovs_bridge');

# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing();
