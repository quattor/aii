use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_yum_setup kickstart_yum_edi);
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

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kickstart_yum_edi');
my $repos = NCM::Component::ks::get_repos($cfg);

my $filter = NCM::Component::ks::make_enable_disable_ignore_repo_filter($cfg);
diag "filter", explain $filter;
is_deeply($filter,
          [['disable*not', 1], ['disable*', 0], ['repo1', -1]],
          "enable/disable/ignore filter");

is(NCM::Component::ks::enable_disable_ignore_repo("disable_me_not", $filter), 1, "enable");
is(NCM::Component::ks::enable_disable_ignore_repo("disable_me_now", $filter), 0, "disable");
is(NCM::Component::ks::enable_disable_ignore_repo("repo1", $filter), -1, "ignore");
ok(!defined(NCM::Component::ks::enable_disable_ignore_repo("repo2", $filter)), "continue");

$repos = NCM::Component::ks::get_repos($cfg);
diag "filtered repos", explain $repos;
is_deeply({map {$_ => $repos->{$_}->{enabled}} keys %$repos},
          {repo0 => 1, disable_me => 0, disable_me_not => 1},
          "filtered enabled/disabled repos");

# no filtering

$cfg = get_config_for_profile('kickstart_yum_setup');
$filter = NCM::Component::ks::make_enable_disable_ignore_repo_filter($cfg);
diag "no filter", explain $filter;
is_deeply($filter, [], "No enable/disable/ignore filter");

$repos = NCM::Component::ks::get_repos($cfg);
diag "unfiltered repos", explain $repos;
is_deeply({map {$_ => $repos->{$_}->{enabled}} keys %$repos},
          {repo0 => 1, repo1 => 1},
          "unfiltered enabled/disabled repos");

my $fh = CAF::FileWriter->new("target/test/ks_yum_setup");
# This module simply prints to the default filehandle.
select($fh);

NCM::Component::ks::yum_setup($ks, $cfg, $repos);

diag "$fh";

my $regexpdir= getcwd()."/src/test/resources/regexps";
Test::Quattor::RegexpTest->new(
    regexp => "$regexpdir/kickstart_yum_setup",
    text => "$fh")->test();

# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing;
