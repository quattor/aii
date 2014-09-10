use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_bootif);
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;

$CAF::Object::NoAction = 1;

my $fh = CAF::FileWriter->new("target/test/ks");
# This module simply prints to the default filehandle.
select($fh);

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kickstart_bootif');

NCM::Component::ks::kscommands($cfg);

like($fh, qr{^network\s--bootproto=dhcp$}m, 'bootif implies dhcp ks');


done_testing();
