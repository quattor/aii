use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_post_script);
use NCM::Component::ks_post_script;

our $this_app = $main::this_app;

$this_app->{CONFIG}->define('osinstalldir');
$this_app->{CONFIG}->set('osinstalldir', '/some/path');

my $obj = Test::Quattor::Object->new();

my $ks = NCM::Component::ks_post_script->new('ks_post_script', $obj);

my $cfg = get_config_for_profile('kickstart_post_script');

$ks->Configure($cfg);

my $fh = get_file('/some/path/kickstart_post_x.y.sh');
like("$fh", qr{# %post phase}, "contains the post code");
unlike("$fh", qr{^%post}m, "does not contain the %post tag");

done_testing;
