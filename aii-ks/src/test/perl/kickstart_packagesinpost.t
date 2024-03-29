use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_packagesinpost);
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
my $cfg = get_config_for_profile('kickstart_packagesinpost');

my ($packref, $repos) = NCM::Component::ks::kscommands($cfg);

diag "kscommands packref ", explain $packref, " repos ", explain $repos, "\n$fh";
like($fh, qr{^%packages --ignoremissing --resolvedeps\n-notthispackage\n%end}m, "Only disabled packages in packages section");
unlike($fh, qr{package2}, "No package2 in commands"); # one of the packages
unlike($fh, qr{bind-utils}, "No bind-utils in commands"); # one of the auto-added packages


$ks->yum_install_packages($cfg, $packref);
diag "yum_install_packages\n$fh";
like($fh, qr{\spackage2}, "package2 added"); # one of the packages
like($fh, qr{\sbind-utils}, "bind-utils added"); # one of the auto-added packages
like($fh, qr{-x\s'notthispackage'},
       "disabled/ignored packages are added to the package install (again) in post");

# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing();
