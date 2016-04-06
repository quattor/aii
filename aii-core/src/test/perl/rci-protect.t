# -*- mode: cperl -*-

use strict;
use warnings;
use CAF::Object;
use Test::Deep;
use Test::More;
use Test::Quattor qw(basic protected);
use Test::MockModule;
use EDG::WP4::CCM::Element;
use CAF::Application;
use CAF::Reporter;
use AII::shellfe;

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

my $mod = AII::shellfe->new(@opts);

my %res = $mod->check_protected(%h);
my @hosts_to_cfg = sort(keys(%res));
cmp_deeply( \@hosts_to_cfg, \@UNPROTECTED_HOSTS, 'only configure unprotected hosts' ) ;

$mod = AII::shellfe->new(@opts, "--protectid", "quattorid_1234" );
%res = $mod->check_protected(%h);
@hosts_to_cfg = sort(keys(%res));
cmp_deeply( \@hosts_to_cfg, \@ALL_HOSTS, 'protectedid given correctly' ) ;

$mod = AII::shellfe->new(@opts, "--protectid", "quattorid_0000" );
%res = $mod->check_protected(%h);
@hosts_to_cfg = sort(keys(%res));
cmp_deeply( \@hosts_to_cfg, \@UNPROTECTED_HOSTS, 'protectedid given wrong' ); 


done_testing();
