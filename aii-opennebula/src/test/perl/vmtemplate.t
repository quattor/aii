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
use CAF::Object;
#use NCM::Component;
use Test::Quattor qw(vmtemplate);
use OpennebulaMock;

my $cfg = get_config_for_profile('vmtemplate');

my $aii = AII::opennebula->new();

my $ttout = $aii->process_template($cfg, "vmtemplate");

like($ttout, qr{^NAME\s+=\s+}m, "Found template NAME");

my $vmtemplate = $aii->get_vmtemplate($cfg);

my $templatename = "node630.cubone.os";

like($ttout, qr{^NAME\s+=\s+"$templatename"\s*$}m, "Found template NAME $templatename");


done_testing();
