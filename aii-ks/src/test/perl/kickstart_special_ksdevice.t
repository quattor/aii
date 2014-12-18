use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_ksdevice_bootif kickstart_ksdevice_link kickstart_ksdevice_mac);
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;

$CAF::Object::NoAction = 1;

my ($fh, $devnet, $ks, $cfg);
foreach my $type (("bootif", "link", "mac")) {
    $fh = CAF::FileWriter->new("target/test/ks_$type");
    # This module simply prints to the default filehandle.

    select($fh);
    $ks = NCM::Component::ks->new('ks');
    $cfg = get_config_for_profile("kickstart_ksdevice_$type");

    $devnet = NCM::Component::ks::ksnetwork_get_dev_net({}, $cfg);
    ok(! defined($devnet), "ksnetwork_get_dev_net for special ksdevice");

    NCM::Component::ks::kscommands($cfg);
    like($fh, qr{^network\s--bootproto=dhcp$}m, "special ksdevice $type implies dhcp ks");

    # close the selected FH and reset STDOUT
    NCM::Component::ks::ksclose;
}

done_testing();
