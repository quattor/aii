=head1 NAME

ks - mock module for the real L<NCM::Component::ks>

=head1 SYNOPSIS

Mock module, to allow the pxelinux module to be loaded.

=cut

package NCM::Component::ks;

use strict;
use warnings;
use parent qw(Exporter);

our @EXPORT_OK = qw(ksuserhooks get_ks_userhook_args get_repos replace_repo_glob);

my $_args;

# unittesting sub
sub get_ks_userhook_args {
    return $_args;
}

sub ksuserhooks { $_args = \@_; }

sub get_repos
{
    my ($config) = @_;

    return {};
}


sub replace_repo_glob
{
    my ($txt, $repos, $noglob, $baseurl_key, $opt_map, $only_one_txt) = @_;

    return $noglob->($txt);
}

1;
