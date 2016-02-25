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

my $fh = CAF::FileWriter->new("target/test/ks");
# This module simply prints to the default filehandle.
select($fh);

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kickstart_mounts');

NCM::Component::ks::ksmountpoints($cfg);
like($fh, qr{^part swap --onpart sdb1 --fstype=swap --fsoptions='auto'\s$}m, 'swap part ok for el7');
unlike ($fh, qr{sdb1.*--noformat}m, 'swap part has no noformat option');
like($fh, qr{raid /boot --device=md1 --noformat --useexisting}m, 'raid with el7 uses useexisting');
# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing();
