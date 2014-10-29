# ${license-info}
# ${developer-info}
# ${author-info}

package AII::freeipa;

use strict;
use warnings;
use CAF::Process;

use constant IPA_CMD => qw(ipa aii);

sub new
{
    my $class = shift;
    return bless {}, $class;
}


#
# Run the ipa aii --disable, to disable the node.
# Disable invalidates the keytab
#
sub ipa_aii_disable
{
    my ($self, $server, $domain) = @_;

    my ($out,$err);
    my $cmd = CAF::Process->new([IPA_CMD, '--disable', $server, $domain],
                                log => $main::this_app,
                                stdout => \$out,
                                stderr => \$err);
    $cmd->execute();
    if ($?) {
        $main::this_app->error ("Couldn't run command: ec $? error $err");
    }
}


#
# Run the ipa aii --install, to prepare the node for installation.
# It returns the OTP
#
sub ipa_aii_install
{
    my ($self, $server, $domain, $client_ip) = @_;
    my @dns = ();
    if ($client_ip) {
        push(@dns, '--ip', $client_ip);
    }

    my ($out,$err);
    my $cmd = CAF::Process->new([IPA_CMD, '--install', @dns, $server, $domain],
                                log => $main::this_app,
                                stdout => \$out,
                                stderr => \$err);
    $cmd->execute();
    if ($?) {
        $main::this_app->error ("Couldn't run command: ec $? error $err");
        return undef;
    }
    my $pwd;
    $pwd = $1 if $out =~ m/randompassword\s+=\s+(\S+)\s*$/m;  # multiline search
    return $pwd;
}

#
# Get the ip of the boot interface. We assume this is
# the IP that corresponds with the hostname when FreeIPA
# DNS configuration is required.
#
sub get_boot_interface_ip
{
    my ($self, $config) = @_;

    my $hardware_nics = $config->getElement("/hardware/cards/nic")->getTree();
    my $network_interfaces = $config->getElement("/system/network/interfaces")->getTree();

    while (my ($nic, $data) = each(%$hardware_nics)) {
        if ($data->{boot}) {
            return $network_interfaces->{$nic}->{ip};
        }
    }
    $main::this_app->error ("No boot IP found");
}

sub post_reboot
{
    my ($self, $config, $path) = @_;

    my $tree = $config->getElement($path)->getTree();

    my $hostname = $config->getElement ('/system/network/hostname')->getValue;
    my $domainname = $config->getElement ('/system/network/domainname')->getValue;

    # FreeIPA DNS control is optional
    my $ip;
    $ip = $self->get_boot_interface_ip($config) if $tree->{dns};

    my $passwd = $self->ipa_aii_install($hostname, $domainname, $ip);

    my $dns = "";
    $dns = "--enable-dns-updates" if $tree->{dns};

    print <<EOF;
yum -c /tmp/aii/yum/yum.conf -y install ipa-client

/usr/sbin/ipa-client-install $dns \\
    --domain=$tree->{domain} \\
    --password=$passwd \\
    --unattended \\
    --realm=$tree->{realm} \\
    --server=$tree->{server} \\
    || fail "ipa-client-install failed"
EOF

    #Extract cert, key and ca files from nssdb if use_nss.
    if ( $tree->{extract_x509} ) {
        $self->extract_x509($config, $hostname, $domainname);
    }

}

#
# Extract x509 certificates from nssdb
#
sub extract_x509 
{
    my ($self, $config, $hostname, $domainname) = @_;
    my $ccm = $config->getElement('/software/components/ccm')->getTree;
    my $ccm_cert_file = $ccm->{cert_file};
    my $ccm_key_file = $ccm->{key_file};
    my $ccm_ca_file = $ccm->{ca_file};
    unless ( $ccm_cert_file =~ /^\// && $ccm_key_file =~ /^\// && $ccm_ca_file =~ /^\// ) {
        $main::this_app->error ("At least one of the paths for cert and/or key and/or ca is not a valid absolute path.");
        return;
    }
    print <<EOF;
mkdir -p `dirname $ccm_cert_file` `dirname $ccm_key_file` `dirname $ccm_ca_file`
certutil -L -d /etc/pki/nssdb -a -n "IPA CA" > $ccm_ca_file
certutil -L -d /etc/pki/nssdb -a -n "IPA Machine Certificate - $hostname.$domainname" > $ccm_cert_file
certutil -K -d /etc/pki/nssdb -a -n "IPA Machine Certificate - $hostname.$domainname"
mkdir /tmp/p12keys
chmod 700 /tmp/p12keys
pk12util -o /tmp/p12keys/keys.p12 -n "IPA Machine Certificate - $hostname.$domainname" -d /etc/pki/nssdb -W ""
openssl pkcs12 -in /tmp/p12keys/keys.p12 -out $ccm_key_file -nodes -password pass:''
chmod 600 $ccm_key_file
rm -rf /tmp/p12keys
EOF

}

sub remove
{
    my ($self, $config, $path) = @_;

    my $tree = $config->getElement ($path)->getTree;
    # TODO proper removal support
    if ($tree->{disable}) {
        my $hostname = $config->getElement ('/system/network/hostname')->getValue;
        my $domainname = $config->getElement ('/system/network/domainname')->getValue;

        $self->ipa_aii_disable($hostname, $domainname);
    }
}


1;
