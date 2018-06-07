use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_mounts);
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<ksmountpoints> method.

=cut

$CAF::Object::NoAction = 1;

my $tdir = "target/test";
mkdir($tdir) if ! -d $tdir;
my $fh = CAF::FileWriter->new("$tdir/ks");
# This module simply prints to the default filehandle.
select($fh);

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kickstart_mounts');

NCM::Component::ks::ksmountpoints($cfg);
diag "ks $fh";

like($fh, qr{^part swap --onpart sdb1 --fstype=swap --fsoptions='auto'\s$}m, 'swap part ok for el7');
unlike ($fh, qr{sdb1.*--noformat}m, 'swap part has no noformat option');
unlike ($fh, qr{(oddfs|mapper)}m, 'mapper/oddfs have aii=false flag');
like($fh, qr{raid /boot --device=md1 --noformat --useexisting}m, 'raid with el7 uses useexisting');
like($fh, qr{logvol /evenfs --vgname=vg0 --name=lv0 --noformat --useexisting}m, 'logvol with el7 uses useexisting');
# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing();
