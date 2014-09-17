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
use Test::Quattor qw(kickstart);
use AII::opennebula;
use CAF::FileWriter;
use CAF::Object;

use OpennebulaMock;

$CAF::Object::NoAction = 1;

my $fh = CAF::FileWriter->new("target/test/ks");
# This module simply prints to the default filehandle.
select($fh);

my $opennebulaaii = new Test::MockModule('AII::opennebula');

my $cfg = get_config_for_profile('kickstart');

my $aii = AII::opennebula->new();
is (ref ($aii), "AII::opennebula", "AII:opennebula correctly instantiated");

my $path;
# test ks install
$path = "/system/aii/hooks/install/0";
$aii->post_reboot($cfg, $path);

like($fh, qr{^yum\s-c\s/tmp/aii/yum/yum.conf\s-y\sinstall\sacpid}m, 'yum install acpid present');
like($fh, qr{^service\sacpid\sstart}m, 'service acpid restart present');

done_testing();
