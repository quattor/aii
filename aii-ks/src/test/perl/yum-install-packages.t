use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kernel-firmware);
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<yum_install_packages> method.

=cut

$CAF::Object::NoAction = 1;

my $fh = CAF::FileWriter->new("target/test/ks");
# This module simply prints to the default filehandle.
select($fh);

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kernel-firmware');

$ks->yum_install_packages($cfg);
like($fh, qr{\bkernel-firmware\b}, "Kernel firmware preserved");
unlike($fh, qr{\bkernel-module-foo\b}, "Kernel module subsumed by glob");

# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing();
