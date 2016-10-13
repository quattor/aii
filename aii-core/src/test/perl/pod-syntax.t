
use Test::More;
use Test::Pod;

my @dirs = qw(target/lib/perl target/sbin target/bin);
all_pod_files_ok(all_pod_files(@dirs));
