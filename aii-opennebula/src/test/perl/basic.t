#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;


use Test::More;
use Test::MockModule;
use Test::Quattor qw(basic);
use AII::opennebula;

use OpennebulaMock;

my $opennebulaaii = new Test::MockModule('AII::opennebula');
$opennebulaaii->mock('make_one', Net::OpenNebula->new());
$opennebulaaii->mock('opennebula_aii_vminstantiate', undef);

my $cfg = get_config_for_profile('basic');

my $aii = AII::opennebula->new();
is (ref ($aii), "AII::opennebula", "AII:opennebula correctly instantiated");

my $one = $aii->make_one();
is (ref($one), "Net::OpenNebula", "returns Net::OpenNebula instance (mocked)");

my $path;
# test remove
rpc_history_reset;

$path = "/system/aii/hooks/remove/0";
$aii->remove($cfg, $path);

#diag_rpc_history;
ok(rpc_history_ok(["one.vmpool.info",
                   "one.imagepool.info",
                   "one.templatepool.info"]),
                   "remove rpc history ok");

# test ks install
rpc_history_reset;

$path = "/system/aii/hooks/install/0";
$aii->install($cfg, $path);

#diag_rpc_history;
ok(rpc_history_ok(["one.vmpool.info",
                   "one.imagepool.info",
                   "one.templatepool.info",
                   "one.template.allocate",
                   "one.template.info",
                   "one.template.instantiate"]),
                   "install rpc history ok");
done_testing();
