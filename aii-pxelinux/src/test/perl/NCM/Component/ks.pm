=head1 NAME

ks - mock module for the real L<NCM::Component::ks>

=head1 SYNOPSIS

Mock module, to allow the pxelinux module to be loaded.

=cut

package NCM::Component::ks;

use strict;
use warnings;
use parent qw(Exporter);

our @EXPORT_OK = qw(ksuserhooks);

sub ksuserhooks {}

1;
