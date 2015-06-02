use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_quattor kickstart_quattor_initspma);
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<ksquattor_config> method with emphasis on logging.

=cut

$CAF::Object::NoAction = 1;

my $fh = CAF::FileWriter->new("target/test/ks_quattor");
# This module simply prints to the default filehandle.
select($fh);

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kickstart_quattor');

NCM::Component::ks::ksquattor_config($cfg);

like($fh, qr{^ulimit -n 8192$}m, 'increase number open filehandles');

like($fh, qr{^cat <<End_Of_CCM_Conf > /etc/ccm.conf$}m, 'initial ccm.conf');
like($fh, qr{^profile https://somewhere/node_profile$}m, 'profile in ccm.conf');
like($fh, qr{^/usr/sbin/ccm-initialise \|\| fail }m, 'ccm-initialise');
like($fh, qr{^/usr/sbin/ccm-fetch \|\| fail }m, 'initial ccm-fetch');
like($fh, qr{^service nscd start$}m, 'service nscd restart');
like($fh, qr{^sleep 5}m, 'sleep after nscd restart');
like($fh, qr{^/usr/sbin/ncm-ncd --verbose  --configure spma || fail "ncm-ncd --configure spma failed"$}m, 'initial ncm-ncd --co spma');
like($fh, qr{^/usr/sbin/ncm-ncd --verbose --configure --all$}m, 'final ncm-ncd --configure -all');

# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

# reopen
$fh = CAF::FileWriter->new("target/test/ks_quattor_initspma");
# This module simply prints to the default filehandle.
select($fh);

$cfg = get_config_for_profile('kickstart_quattor_initspma');
NCM::Component::ks::ksquattor_config($cfg);
like($fh, qr{^/usr/sbin/ncm-ncd --verbose --ignore-errors-from-dependencies --configure spma || fail "ncm-ncd --configure spma failed"$}m,
     'initial ncm-ncd --co spma with --ignore-errors-from-dependencies');

# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing();
