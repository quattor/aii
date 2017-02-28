use strict;
use warnings;
use Test::More;
use Test::Quattor;
use NCM::Component::PXELINUX::constants qw(:pxe_variants);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;


=pod

=head1 SYNOPSIS

Tests for the C<_hexip_filename> method.

=cut

$CAF::Object::NoAction = 1;

our $this_app = $main::this_app;

my $ip = "133.2.85.234";

my $comp = NCM::Component::pxelinux->new('hexip_filename');

my $hepix_str = $comp->_hexip_filename($ip, PXE_VARIANT_PXELINUX);
is($hepix_str, "850255EA", "filename from IP (PXELINUX variant)");

$hepix_str = $comp->_hexip_filename($ip, PXE_VARIANT_GRUB2);
is($hepix_str, "grub.cfg-850255EA", "filename from IP (Grub2 variant)");


done_testing();
