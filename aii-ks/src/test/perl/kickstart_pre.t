use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_pre_noblock kickstart_pre_blocksize);
use Test::Quattor::RegexpTest;
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;
use Cwd;

=pod

=head1 SYNOPSIS

Tests for generating the pre section.

=cut

$CAF::Object::NoAction = 1;

my $regexpdir= getcwd()."/src/test/resources/regexps";

my @tests = qw(noblock blocksize);
foreach my $test (@tests) {
    my $fh = CAF::FileWriter->new("target/test/ks_pre_noblock_$test");
    # This module simply prints to the default filehandle.
    select($fh);
    
    my $ks = NCM::Component::ks->new('ks');
    my $cfg = get_config_for_profile("kickstart_pre_$test");
    
    $ks->pre_install_script($cfg);
    
    # close the selected FH and reset STDOUT for diag/note output
    NCM::Component::ks::ksclose;

    note("PRE text $fh");
    my @regexps = qw(functions logging blockdevices);
    foreach my $regexptest (@regexps) {
        my $regexp = "$regexpdir/pre_${test}_$regexptest";
        Test::Quattor::RegexpTest->new(regexp => $regexp, text => "$fh")->test() if (-f $regexp);
    }
};

done_testing();
