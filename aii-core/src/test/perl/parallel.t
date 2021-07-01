# -*- mode: cperl -*-

use strict;
use warnings;
use CAF::Object;
use Test::More;
use Test::Quattor qw(basic);
use Test::MockModule;
use CAF::Application;
use CAF::Reporter;
use AII::Shellfe;

use Readonly;

$CAF::Object::NoAction = 1;

my $caflock = Test::MockModule->new('CAF::Lock');
my $cfg_basic = get_config_for_profile('basic');
my $config_basic = { configuration => $cfg_basic };
my %h = (map {("test$_.cluster", {configuration => $cfg_basic, name => "test$_.cluster"})} qw(01 02 03 04));

my $defres = {};
foreach my $host (keys %h) {
	$defres->{$host} = {
    	'ec' => 0,
    	'mode' => 0,
    	'node' => $host,
	};
};

$caflock->mock('set_lock', 1 );
my @opts = qw(script
    --logfile target/test/parallel.log
    --cfgfile src/test/resources/parallel.cfg
    --debug 5
);

my $mod = AII::Shellfe->new(@opts);

my ($pm, %responses) = $mod->init_pm('test');
ok(!$pm, 'parallel fork manager not initiated');


foreach my $host (keys %h) {
	$defres->{$host}->{method} = '_remove';
};

my $ok = $mod->remove(%h);
is_deeply( $ok, $defres, 'correct result' ) ;

$mod = AII::Shellfe->new(@opts, "--parallel", 2 );
($pm, %responses) = $mod->init_pm('test');
ok($pm, 'parallel fork manager initiated p=2');

foreach my $host (keys %h) {
	$defres->{$host}->{mode} = 1;
};
$ok = $mod->remove(%h);
is_deeply($ok, $defres, 'correct remove resul p=2t' ) ;

foreach my $host (keys %h) {
	$defres->{$host}->{method} = '_status';
};
$ok = $mod->status(%h);
is_deeply($ok, $defres, 'correct status result p=2' ) ;


$mod = AII::Shellfe->new(@opts, "--parallel", 4 );
($pm, %responses) = $mod->init_pm('test');
ok($pm, 'parallel fork manager initiated p=4');

$ok = $mod->status(%h);
is_deeply( $ok, $defres, 'correct result p=4' ) ;

foreach my $host (keys %h) {
	$defres->{$host}->{method} = '_configure';
};
$ok = $mod->configure(%h);
diag " configure p=4 ok ", explain $ok, explain $defres;
is_deeply( $ok, $defres, 'correct configure result p=4' ) ;

foreach my $host (keys %h) {
	$defres->{$host}->{method} = '_install';
};
$ok = $mod->install(%h);
is_deeply( $ok, $defres, 'correct install result p=4' ) ;

done_testing();
