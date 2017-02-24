# -*- mode: cperl -*-

use strict;
use warnings;
use CAF::Object;
use Test::Deep;
use Test::More;
use Test::Quattor qw(basic);
use Test::MockModule;
use EDG::WP4::CCM::Element;
use CAF::Application;
use CAF::Reporter;
use AII::Shellfe;

use Readonly;

$CAF::Object::NoAction = 1;

my $caflock = Test::MockModule->new('CAF::Lock');
my $cfg_basic = get_config_for_profile('basic');
my $config_basic = { configuration => $cfg_basic };
my %h = (
    'test01.cluster' => $config_basic,
    'test02.cluster' => $config_basic,
    'test03.cluster' => $config_basic,
    'test04.cluster' => $config_basic,
);
my $defres = {};
foreach my $host (keys %h) {
	$defres->{$host} = {
    	'ec' => 0,
    	'mode' => 0,
    	'node' => $host,
	};
};

$caflock->mock('set_lock', 1 );
my @opts = qw(script --logfile=target/test/parallel.log --cfgfile=src/test/resources/parallel.cfg);



my $mod = AII::Shellfe->new(@opts);

my ($pm, %responses) = $mod->init_pm('test');
ok(!$pm, 'parallel fork manager not initiated');


foreach my $host (keys %h) {
	$defres->{$host}->{method} = '_remove';
};

my $ok = $mod->remove(%h);
cmp_deeply( $ok, $defres, 'correct result' ) ;

$mod = AII::Shellfe->new(@opts, "--parallel", 2 );
($pm, %responses) = $mod->init_pm('test');
ok($pm, 'parallel fork manager initiated');

foreach my $host (keys %h) {
	$defres->{$host}->{mode} = 1;
};
$ok = $mod->remove(%h);
cmp_deeply( $ok, $defres, 'correct result' ) ;

foreach my $host (keys %h) {
	$defres->{$host}->{method} = '_status';
};
$ok = $mod->status(%h);
cmp_deeply( $ok, $defres, 'correct result' ) ;


$mod = AII::Shellfe->new(@opts, "--parallel", 4 );
($pm, %responses) = $mod->init_pm('test');
ok($pm, 'parallel fork manager initiated');

$ok = $mod->status(%h);
cmp_deeply( $ok, $defres, 'correct result' ) ;

foreach my $host (keys %h) {
	$defres->{$host}->{method} = '_configure';
};
$ok = $mod->configure(%h);
cmp_deeply( $ok, $defres, 'correct result' ) ;

foreach my $host (keys %h) {
	$defres->{$host}->{method} = '_install';
};
$ok = $mod->install(%h);
cmp_deeply( $ok, $defres, 'correct result' ) ;

done_testing();
