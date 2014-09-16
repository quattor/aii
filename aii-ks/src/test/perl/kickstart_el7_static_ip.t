use strict;
use warnings;
use Test::More;
use Test::Quattor qw(kickstart_el7_static_ip);
use NCM::Component::ks;
use CAF::FileWriter;
use CAF::Object;

=pod

=head1 SYNOPSIS

Tests for the C<kscommands> method.

=cut

$CAF::Object::NoAction = 1;

my $fh = CAF::FileWriter->new("target/test/ks");
# This module simply prints to the default filehandle.
select($fh);

my $ks = NCM::Component::ks->new('ks');
my $cfg = get_config_for_profile('kickstart_el7_static_ip');

NCM::Component::ks::kscommands($cfg);

like($fh, qr{^cmdline}m, 'cmdline mode install present');

like($fh, qr{^reboot}m, 'reboot after install present');
like($fh, qr{^skipx}m, 'skip x configuration present');
like($fh, qr{^auth\s--enableshadow\s--enablemd5}m, 'authentication parameters present');
like($fh, qr{^install\n^url\s--url http://baseos}m, 'installtype present');
like($fh, qr{^timezone\s--utc Europe/SomeCity}m, 'timezone present');
like($fh, qr{^rootpw\s--iscrypted veryverysecret}m, 'crypted root password present');
like($fh, qr{^bootloader\s--location=mbr}m, 'bootloader present');
like($fh, qr{^lang\sen_US.UTF-8}m, 'lang setting present');
like($fh, qr{^keyboard\s--xlayouts=us}m, 'keyboard present (with xlayouts)');
like($fh, qr{^firewall\s--disabled }m, 'firewall disabled present');
like($fh, qr{^network\s--bootproto=static\s--device=eth0\s--hostname=x.y\s--nameserver=nm1\s--ip=1.2.3.0\s--netmask=255.255.255.0\s--gateway=1.2.3.4}m, ' present');
like($fh, qr{^zerombr$}m, 'zerombr present (no yes)');
like($fh, qr{^services\s--disabled=disable1,DISABLE2\s--enabled=enable1,ENABLE2}m, "--dis/enable services present");
like($fh, qr{^sshpw\s--username=root\sveryverysecret\s--iscrypted}m, "sshd enabled");

like($fh, qr{^eula --agreed$}m, 'eula agreed');

like($fh, qr{^%packages\s--ignoremissing\s--resolvedeps\n^package\n^package2\nbind-utils\n^EENNDD\n}m, 'installtype present');


done_testing();
