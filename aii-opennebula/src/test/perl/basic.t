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
$opennebulaaii->mock('is_timeout', undef);

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
                   "one.image.delete",
                   "one.imagepool.info",
                   "one.vnpool.info",
                   "one.vn.rm_ar",
                   "one.vnpool.info",
                   "one.templatepool.info",
                   "one.template.delete"]),
                   "remove rpc history ok");
# test configure
rpc_history_reset;

$path = "/system/aii/hooks/configure/0";
$aii->configure($cfg, $path);
#diag_rpc_history;
ok(rpc_history_ok(["one.vmpool.info",
                   "one.imagepool.info",
                   "one.image.delete",
                   "one.imagepool.info",
                   "one.imagepool.info",
                   "one.imagepool.info",
                   "one.datastorepool.info",
                   "one.image.allocate",
                   "one.image.info",
                   "one.image.chmod",
                   "one.userpool.info",
                   "one.grouppool.info",
                   "one.image.chown",
                   "one.vnpool.info",
                   "one.vn.update_ar",
                   "one.vnpool.info",
                   "one.vn.add_ar",
                   "one.templatepool.info",
                   "one.template.delete",
                   "one.template.allocate",
                   "one.template.info",
                   "one.template.chmod",
                   "one.userpool.info",
                   "one.grouppool.info",
                   "one.template.chown"]),
                   "configure rpc history ok");

# test ks install
rpc_history_reset;

$path = "/system/aii/hooks/install/0";
$aii->install($cfg, $path);
#diag_rpc_history;
ok(rpc_history_ok(["one.vmpool.info",
                   "one.templatepool.info",
                   "one.imagepool.info",
                   "one.image.info",
                   "one.template.instantiate"]),
                   "install rpc history ok");

done_testing();
