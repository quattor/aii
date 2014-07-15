#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

use OpennebulaMock;

use Test::More;

use CAF::Object;
#use NCM::Component;
use Test::Quattor qw(basic);

use AII::opennebula;
my $opennebulaaii = new Test::MockModule('AII::opennebula');
$opennebulaaii->mock('make_one', Net::OpenNebula->new());

my $cfg = get_config_for_profile('basic');
#my $cmp = NCM::Component->new("dummy");

my $aii = AII::opennebula->new();
is (ref ($aii), "AII::opennebula", "AII:opennebula correctly instantiated");

my $one = $aii->make_one();
is (ref($one), "Net::OpenNebula", "returns Net::OpenNebula instance (mocked)");

my $path;
# test remove
command_history_reset;

$path = "/system/aii/hooks/remove/0";
$aii->remove($cfg, $path);

# test ks install
command_history_reset;

$path = "/system/aii/hooks/install/0";
$aii->install($cfg, $path);

done_testing();
