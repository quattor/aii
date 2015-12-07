use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_yum_setup);
use Test::Quattor::RegexpTest;
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;
use Cwd;

=pod

=head1 SYNOPSIS

Tests for the C<yum_setup> method.

=cut

$CAF::Object::NoAction = 1;

my $fh = CAF::FileWriter->new("target/test/ks_yum_setup");
# This module simply prints to the default filehandle.
select($fh);

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kickstart_yum_setup');

NCM::Component::ks::yum_setup($ks, $cfg);

diag "$fh";

my $regexpdir= getcwd()."/src/test/resources/regexps";
Test::Quattor::RegexpTest->new(
    regexp => "$regexpdir/kickstart_yum_setup",
    text => "$fh")->test();

# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing;
