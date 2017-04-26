# -*- mode: cperl -*-

use strict;
use warnings;
use CAF::Object;
use Test::Deep;
use Test::More;
use Test::Quattor qw(basic protected);
use Test::MockModule;
use CAF::Application;
use CAF::Reporter;
use AII::Shellfe;

use Readonly;

$CAF::Object::NoAction = 1;

my $cfg_basic = get_config_for_profile('basic');
my $cfg_protected = get_config_for_profile('protected');
my $config_basic = { configuration => $cfg_basic };
my $config_protected = { configuration => $cfg_protected };
my %h = (
    'test01.cluster' => $config_basic,
    'test02.cluster' => $config_protected,
    'test03.cluster' => $config_protected,
    'test04.cluster' => $config_basic,
);

my @opts = qw(script --logfile=target/test/rci-protect.log --cfgfile=src/test/resources/rci-protect.cfg);

Readonly::Array my @UNPROTECTED_HOSTS => ('test01.cluster', 'test04.cluster');
Readonly::Array my @ALL_HOSTS => sort(keys(%h));

my $mod = AII::Shellfe->new(@opts);

my %res = $mod->check_protected(%h);
my @hosts_to_cfg = sort(keys(%res));
cmp_deeply( \@hosts_to_cfg, \@UNPROTECTED_HOSTS, 'only configure unprotected hosts' ) ;

$mod = AII::Shellfe->new(@opts, "--confirm", "quattorid_1234" );
%res = $mod->check_protected(%h);
@hosts_to_cfg = sort(keys(%res));
cmp_deeply( \@hosts_to_cfg, \@ALL_HOSTS, 'correct confirmation given' ) ;

$mod = AII::Shellfe->new(@opts, "--confirm", "quattorid_0000" );
%res = $mod->check_protected(%h);
@hosts_to_cfg = sort(keys(%res));
cmp_deeply( \@hosts_to_cfg, \@UNPROTECTED_HOSTS, 'wrong confirmation given' );


done_testing();
