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
use Test::Quattor qw(images);
use OpennebulaMock;

my $cfg = get_config_for_profile('images');

my $aii = AII::opennebula->new();

my $ttout = $aii->process_template($cfg, "imagetemplate");

like($ttout, qr{^DATASTORE\s+=\s+}m, "Found DATASTORE");

my %images = $aii->get_images($cfg);

my $imagea = "node630.cubone.os_vda";
my $imageb = "node630.cubone.os_vdb";

ok(exists($images{$imagea}), "image a exists");
ok(exists($images{$imageb}), "image b exists");

is($images{$imagea}{datastore}, "ceph", "datastore of image a is ceph");
is($images{$imageb}{datastore}, "default", "datastore of image b is default");

like($images{$imagea}{image}, qr{^TARGET\s+=\s+"vda"\s*$}m, "image a contains TARGET vda");
like($images{$imageb}{image}, qr{^TARGET\s+=\s+"vdb"\s*$}m, "image b contains TARGET vdb");


done_testing();
