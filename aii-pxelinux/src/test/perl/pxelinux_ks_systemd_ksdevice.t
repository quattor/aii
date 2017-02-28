use strict;
use warnings;
use Test::More;
use Test::Quattor qw(
    pxelinux_ks_ksdevice_systemd_scheme_1
    pxelinux_ks_ksdevice_systemd_scheme_2
    pxelinux_ks_ksdevice_systemd_scheme_3
    pxelinux_ks_ksdevice_systemd_scheme_4
);
use NCM::Component::pxelinux;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<_write_pxelinux_config> method.

=cut

$CAF::Object::NoAction = 1;

my $mockpxe = Test::MockModule->new('NCM::Component::pxelinux');

my @scheme_data = qw(eno1 ens1 enp2s0 enx78e7d1ea46da);

my ($fp, $comp, $cfg, $bond, $fh, $search, $regtxt);
foreach my $scheme (qw(1 2 3 4)) {
    # mock _filepath, it has this_app->option
    $fp = "target/test/pxelinux_$scheme";
    $mockpxe->mock('_filepath', $fp);

    $comp = NCM::Component::pxelinux->new('pxelinux_ks');
    $cfg = get_config_for_profile("pxelinux_ks_ksdevice_systemd_scheme_$scheme");

    $search = $scheme_data[$scheme-1];

    $bond = $comp->_pxe_network_bonding($cfg, {}, $search);
    ok(! defined($bond), "Bonding for unsupported device $search returns undef");

    $comp->_write_pxelinux_config($cfg);

    $fh = get_file($fp);

    $regtxt = '^\s{4}append\s.*?\sksdevice='.$search.'(\s|$)';
    like($fh, qr{$regtxt}m, "ksdevice=$search for ksdevice $scheme");
    if ($scheme eq "bootif") {
        like($fh, qr{^\s{4}ipappend\s2$}m, "ipappend 2 for ksdevice $scheme");
    }
}

done_testing();
