#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use version;
use Test::More;
use AII::opennebula;
use Test::MockModule;
use Test::Quattor qw(aii_vmtemplate);
use OpennebulaMock;

my $cfg = get_config_for_profile('aii_vmtemplate');
my $opennebulaaii = new Test::MockModule('AII::opennebula');
$opennebulaaii->mock('make_one', Net::OpenNebula->new(url  => "http://localhost/RPC2",
                                                      user => "oneadmin",));

my $aii = AII::opennebula->new();
my $oneversion = version->new("5.0.0");

my $ttout = $aii->process_template($cfg, "vmtemplate", $oneversion);

like($ttout, qr{^NAME\s+=\s+}m, "Found template NAME");

my $vmtemplate = $aii->get_vmtemplate($cfg, $oneversion);

my $templatename = "node630.cubone.os";

like($ttout, qr{^NAME\s+=\s+"$templatename"\s*$}m, "Found template NAME $templatename");

my $one = $aii->make_one();

# Check VM template creation
rpc_history_reset;
$aii->remove_and_create_vm_template($one, $templatename, 1, $vmtemplate);
#diag_rpc_history;
ok(rpc_history_ok(["one.templatepool.info",
                   "one.template.delete",
                   "one.template.allocate",
                   "one.template.info"]),
                   "remove_and_create_vm_template install rpc history ok");

# Check VM template update
rpc_history_reset;
$aii->remove_and_create_vm_template($one, $templatename, 0, $vmtemplate);
ok(rpc_history_ok(["one.templatepool.info",
                   "one.template.update"]),
                   "remove_and_create_vm_template update rpc history ok");

# Check VM template remove
rpc_history_reset;
$aii->remove_and_create_vm_template($one, $templatename, 1, $vmtemplate, undef, 1);
ok(rpc_history_ok(["one.templatepool.info",
                   "one.template.delete"]),
                   "remove_and_create_vm_template remove rpc history ok");

done_testing();
