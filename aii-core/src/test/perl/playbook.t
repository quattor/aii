use strict;
use warnings;
use Test::More;
use Test::Quattor;
use Test::Quattor::Object;
use Cwd;

use AII::Playbook;

$CAF::Object::NoAction = 1;

my $obj = Test::Quattor::Object->new();

my $pb = AII::Playbook->new("myhost", log => $obj);

my $root = getcwd . "/target/test/playbook/myhost";

$pb->write($root);

# No roles
my $fh = get_file("$root/main.yml");
is("$fh", "---\n- hosts: myhost\n  roles: []\n");

# Add role
my $role = $pb->add_role("first");
isa_ok ($role, "AII::Role", "Correct class after add_role");
my $task = $role->add_task("task1");
isa_ok ($task, "AII::Task", "Correct class after add_task");

$task = $role->add_task("task2");

$role = $pb->add_role("second");
$task = $role->add_task("task3", {some => 'thing'});

$pb->write($root);

# No roles
$fh = get_file("$root/main.yml");
is("$fh", "---\n- hosts: myhost\n  roles:\n  - first\n  - second\n");
$fh = get_file("$root/roles/first.yml");
is("$fh", "---\n- tasks:\n  - name: task1\n  - name: task2\n");
$fh = get_file("$root/roles/second.yml");
is("$fh", "---\n- tasks:\n  - name: task3\n    some: thing\n");


done_testing;
