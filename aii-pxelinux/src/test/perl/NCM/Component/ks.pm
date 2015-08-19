=head1 NAME

ks - mock module for the real L<NCM::Component::ks>

=head1 SYNOPSIS

Mock module, to allow the pxelinux module to be loaded.

=cut

package NCM::Component::ks;

use strict;
use warnings;
use parent qw(Exporter);

our @EXPORT_OK = qw(ksuserhooks get_ks_userhook_args);

my $_args;

# unittesting sub
sub get_ks_userhook_args {
    return $_args;
}

sub ksuserhooks { $_args = \@_; }

1;
