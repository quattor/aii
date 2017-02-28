use strict;
use warnings;
use Test::More;
use Test::Quattor qw(pxelinux_ks_ksdevice_bootif pxelinux_ks_ksdevice_mac pxelinux_ks_ksdevice_link);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<_write_pxelinux_config> method.

=cut

$CAF::Object::NoAction = 1;

my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');

my ($fp, $comp, $cfg, $bond, $fh, $search, $regtxt);
foreach my $type (("bootif", "link", "mac")) {
    # mock _filepath, it has this_app->option
    $fp = "target/test/pxelinux_$type";
    $mockpxe->mock('_filepath', $fp);
    
    $comp = NCM::Component::pxelinux->new('pxelinux_ks');
    $cfg = get_config_for_profile("pxelinux_ks_ksdevice_$type");

    $search = $type;
    $search = "AA:BB:CC:DD:EE:FF" if ($type eq "mac"); 
    
    $bond = $comp->_pxe_network_bonding($cfg, {}, $search);
    ok(! defined($bond), "Bonding for unsupported device $search returns undef");
    
    $comp->_write_pxelinux_config($cfg);
    
    $fh = get_file($fp);
    
    $regtxt = '^\s{4}append\s.*?\sksdevice='.$search.'(\s|$)';
    like($fh, qr{$regtxt}m, "ksdevice=$search for ksdevice $type");
    if ($type eq "bootif") {
        like($fh, qr{^\s{4}ipappend\s2$}m, "ipappend 2 for ksdevice $type");
    }
}

done_testing();
