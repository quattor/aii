#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use Test::More;
use AII::freeipa;
use NCM::Component::ks
use CAF::Object;
#use NCM::Component;
use Test::Quattor qw(basic);

use helper;

my $cfg = get_config_for_profile('basic');
#my $cmp = NCM::Component->new("dummy");

my $aii = AII::freeipa->new();
is (ref ($aii), "AII::freeipa", "AII:freeipa correctly instantiated");

my $path;
#
command_history_reset;
set_output("disable");

$path = "/system/aii/hooks/remove/0";
$aii->remove($cfg, $path);
ok(command_history_ok(["ipa aii --disable x y.z"]), 
    "ipa aii --disable called");

# test ks post 
command_history_reset;
set_output("install_ip");

my $fh = CAF::FileWriter->new("target/test/ks");
select($fh);

$aii->post_reboot($cfg, $path);

ok(command_history_ok(["ipa aii --install --ip 5.6.7.8 x y.z"]), 
    "ipa aii --install --ip called");

like($fh, qr(^/usr/sbin/ipa-client-install.*\\$)m, "Call ipa-client-install");
like($fh, qr/\s--domain=z\s+\\$/m, "FreeIPA params domain");
like($fh, qr/\s--password=onetimepassword\s+\\$/m, "FreeIPA params password");
like($fh, qr/\s--realm=DUMMY\s+\\$/m, "FreeIPA params realm");
like($fh, qr/\s--server=ipa.y.z\s+\\$/m, "FreeIPA params server");
like($fh, qr/\s--unattended\s+\\$/m, "FreeIPA params unattended");
like($fh, qr(--enable-dns-updates)m, "IPA dns enabled");

like($fh, qr(^yum -c /tmp/aii/yum/yum.conf -y install ipa-client)m, "install ipa-client in post_reboot");

# close the selected FH and reset STDOUT
NCM::Component::ks::ksclose;

done_testing();
