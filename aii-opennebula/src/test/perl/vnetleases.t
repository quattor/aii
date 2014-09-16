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
use Test::Quattor qw(vnetleases);
use OpennebulaMock;

my $cfg = get_config_for_profile('vnetleases');

my $aii = AII::opennebula->new();

my $ttout = $aii->process_template($cfg, "vnetleases");

like($ttout, qr{^NETWORK\s+=\s+}m, "Found vnet NETWORK name");

my %networks = $aii->get_vnetleases($cfg);

my $networka = "altaria.os";
my $networkb = "altaria.vsc";

ok(exists($networks{$networka}), "vnet a exists");
ok(exists($networks{$networkb}), "vnet b exists");

is($networks{$networka}{network}, "altaria.os", "vneta name is altaria.os");
is($networks{$networkb}{network}, "altaria.vsc", "vnetb name is altaria.vsc");

like($networks{$networka}{lease}, qr{^LEASES=\[IP=.+,\s+MAC=.+\]$}m, "vnet a contains LEASES info");
like($networks{$networkb}{lease}, qr{^LEASES=\[IP=.+,\s+MAC=.+\]$}m, "vnet b contains LEASES info");


done_testing();
