#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use Test::More;
use AII::opennebula;
use Test::MockModule;
use Test::Quattor qw(aii_network_ar);
use OpennebulaMock;

my $cfg = get_config_for_profile('aii_network_ar');

my $aii = AII::opennebula->new();

my $ttout = $aii->process_template($cfg, "aii_network_ar");

like($ttout, qr{^NETWORK\s+=\s+}m, "Found vnet NETWORK name");

my %networks = $aii->get_vnetars($cfg);

my $networka = "altaria.os";
my $networkb = "altaria.vsc";

ok(exists($networks{$networka}), "vnet a exists");
ok(exists($networks{$networkb}), "vnet b exists");

is($networks{$networka}{network}, "altaria.os", "vneta name is altaria.os");
is($networks{$networkb}{network}, "altaria.vsc", "vnetb name is altaria.vsc");

#like($networks{$networka}{lease}, qr{^LEASES\s+=\s+\[IP=.+,\s+MAC=.+\]$}m, "vnet a contains LEASES info");
#like($networks{$networkb}{lease}, qr{^LEASES\s+=\s+\[IP=.+,\s+MAC=.+\]$}m, "vnet b contains LEASES info");


done_testing();
