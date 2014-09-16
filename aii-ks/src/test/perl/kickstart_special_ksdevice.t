use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_ksdevice_bootif kickstart_ksdevice_link kickstart_ksdevice_mac);
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;

$CAF::Object::NoAction = 1;

my ($fh, $ks, $cfg);
foreach my $type (("bootif", "link", "mac")) {
    $fh = CAF::FileWriter->new("target/test/ks_$type");
    # This module simply prints to the default filehandle.
    select($fh);
    $ks = NCM::Component::ks->new('ks');
    $cfg = get_config_for_profile("kickstart_ksdevice_$type");
    use Data::Dumper;
    diag("MY TYPE $type ".Dumper(\$cfg));
    NCM::Component::ks::kscommands($cfg);
    like($fh, qr{^network\s--bootproto=dhcp$}m, "special ksdevice $type implies dhcp ks");
}

done_testing();
