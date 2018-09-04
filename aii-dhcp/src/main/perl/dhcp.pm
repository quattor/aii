#${PMpre} NCM::Component::dhcp${PMpost}

use Socket;

use Exporter;
use Sys::Hostname;
use CAF::Lock qw (FORCE_IF_STALE);
use CAF::FileReader;
use CAF::FileWriter;
use CAF::Process;

# locking configuration
use constant TIMEOUT => 60;
use constant RETRIES => 6;

use parent qw(NCM::Component Exporter);
our $EC = LC::Exception::Context->new->will_store_all;
our $this_app = $main::this_app;

sub finish
{
    my ($self) = @_;
    $self->restart_daemon();
}

#
# restart_daemon()
#
# restart dhcp daemon
#
sub restart_daemon
{
    my ($self) = @_;

    my ($cmd, $output);
    $self->debug(3, "aii-dhcp: restarting daemon dhcpd");

    $cmd = $this_app->option('restartcmd');
    if (!$cmd) {
        $self->verbose("aii-dhcp: no command defined to restart dhcpd");
    } else {
        $output = CAF::Process->new([$cmd], log => $self)->output();
        if ($? == 0) {
            $self->verbose("aii-dhcp: daemon restarted: $output");
        } else {
            $self->error("aii-dhcp: error restarting dhcp daemon: $output");
            return 1;
        }
    }

    return 0;
}

#
# update_dhcp_config_file($text, $ntc, $ntr)
#
# Remove and add host declarations
#
sub update_dhcp_config_file
{
    my ($self, $text, $ntc, $ntr) = @_;
    my @NTC = @$ntc;
    my @NTR = @$ntr;
    my ($nodes_regexp, $node);

    #
    # Remove existing nodes (both NodesToConfigure and NodesToRemove)
    #
    $nodes_regexp = '';
    foreach $node (@NTC, @NTR) {
        $nodes_regexp .= $node->{NAME} . '|' . $node->{FQDN} . '|';
    }
    $nodes_regexp =~ s/\|$//; # remove last '|'
    $nodes_regexp = '\\n\s*host\s+(' . $nodes_regexp . ')\s*(\{(?:[^{}]|(?2))*\})';
    $text =~ s/$nodes_regexp//gm;

    #
    # Collect the subnets + netmask definitions
    #
    # Fix for bug #10455: regexp should not match comment lines
    #
    my @netandmasks = ($text =~
                       /\n\s*subnet\s+([\d\.]+)\s+netmask\s+([\d\.]+)/g);
    if ($#netandmasks % 2 == 0) {
        $self->error("aii-dhcp: syntax error on dhcpd.conf: " .
                    "netmask/network missing in subnet declaration");
        return(1, '');
    }
    my (@subnets, $i);
    for ($i=0 ; $i<$#netandmasks ; $i=$i+2) {
        push (@subnets, {
                NET     => unpack('N',Socket::inet_aton($netandmasks[$i])),
                MASK    => unpack('N',Socket::inet_aton($netandmasks[$i+1])),
                ST_NET  => $netandmasks[$i],
                ST_MASK => $netandmasks[$i+1],
              });
        $self->verbose("aii-dhcp: found subnet $netandmasks[$i] " .
                       "mask $netandmasks[$i+1]");
    }
    # If subnets are not defined in the DHCP configuration file managed by AII,
    # just add an empty subnet. This will have the effect of disabling all the checks
    # related to subnets.
    if ( @subnets == 0 ) {
        push (@subnets,{})
    }

    #
    # for each subnet, write entries that belong to it
    #
    my ($net, $mac, $newnodes, $netfound);
    my $subnet_defined = 1;
    my $indent = "  "; # from aii-dhcp line 421-424
    if ( @subnets == 0 ) {
        push (@subnets, {});
        $subnet_defined = 0;
    }
    foreach $net (@subnets) {
        my @newnodes;

        foreach $node (@NTC) {

            # Does the node belong to this subnet?
            # Always true if no subnet defined.
            if ( !$subnet_defined || (($node->{IP} & $net->{MASK}) == $net->{NET}) ) {

                $node->{OK} = 1;

                # basic host declaration
                push @newnodes, "\n".$indent."host $node->{NAME} {  # added by aii-dhcp";

                foreach $mac (split(' ', $node->{MAC})) {
                    push @newnodes, "$indent\t  hardware ethernet $mac;";
                }

                push @newnodes, "$indent\t  fixed-address $node->{ST_IP};";

                # TFTP server
                if ($node->{ST_IP_TFTP}) {
                    push @newnodes, "$indent\t  next-server $node->{ST_IP_TFTP};";
                }

                # DHCP filename option
                if ($node->{FILENAME}) {
                    push @newnodes, "$indent\t  filename \"$node->{FILENAME}\";";
                }

                # additional options
                if ($node->{MORE_OPT}) {
                    push @newnodes, "$indent\t  $node->{MORE_OPT}";
                }

                push @newnodes, "$indent\t}";
                if ( $subnet_defined ) {
                    $self->verbose("aii-dhcp: added node $node->{NAME} ".
                                   "to subnet $net->{ST_NET}");
                } else {
                    $self->verbose("aii-dhcp: added node $node->{NAME} (no subnet specified)");
                }
            }

        }

        # Insert the nodes to the current subnet
        if (@newnodes) {
            $self->debug(1,"aii-dhcp: newnodes=|@newnodes|\n");
            my @text = split /\n/,$text;
            my $index = 0;
            my $braces = 0;
            my $found_net;
            if ( $subnet_defined ) {
                $found_net = 0;
            } else {
                $found_net = 1;
            }

            for my $line (@text) {
                $index++;
                if ($line !~ /\s* subnet \s+/x) {
                    next unless $found_net > 0;
                }
                if ($line =~ /\s* subnet \s+ \Q$net->{ST_NET}\E \s+ netmask \s+ \Q$net->{ST_MASK}\E/x ) {
                    $found_net = 1;
                    $braces++;
                    next;
                }
                if ($line =~ /\{/x) {
                    $braces++;
                } elsif ($line =~ /\}/x) {
                    $braces--;
                }
                if ($braces == 0) {
                    # we've run out of network definition!
                    $index--;
                    last;
                }
                if ($line =~ /group\s+\{\s+\#\s+PXE/) {
                    last;
                }
            }
            if ($found_net) {
                splice @text, $index, 0, @newnodes;
            }
            $text = join("\n", @text);
        }

    }

    #
    # Just a stupid check for nodes not inserted
    #
    foreach $node (@NTC) {
        ($node->{OK}) || $self->warn("dhcp: No valid subnet found " .
                                     "for $node->{FQDN}");
    }

    return (0, $text);

}

#
# get_ip()
#
# Determine the IP address of the interface
#
# The passed interface is a hardware device, however the IP address may be
# configured on a logical interface on top of the HW. Currently only
# bonding is supported.
sub get_ip {
    my ($self, $iface, $tree) = @_;

    # Single redirection for bonding devices
    if (defined($tree->{interfaces}->{$iface}->{master})) {
        $iface = $tree->{interfaces}->{$iface}->{master};
    }

    return $tree->{interfaces}->{$iface}->{ip};
}

#
# update_dhcp_config()
#
# Update DHCP configuration file
#
sub update_dhcp_config {
    my ($self, $ntc, $ntr) = @_;
    my ($filename, $text, $error, $lockfile);

    #
    # Lock and load the current dhcp configuration file
    #
    $filename = $this_app->option('dhcpconf');
    if (!$filename) {
        $self->error("no dhcp configuration file defined!");
        return(1);
    }
    $lockfile = $filename . ".lock";
    my $lock = CAF::Lock->new ($lockfile);
    unless ($lock && $lock->set_lock (RETRIES, TIMEOUT, FORCE_IF_STALE)) {
        $self->error("dhcp: couldn't acquire lock on $lockfile");
        return(1);
    }
    $self->debug(3, "Locked dhcp configuration");
    $self->debug(3,"DHCP configuration file : $filename");
    my $fh = CAF::FileReader->new($filename, log => $self);
    if ($EC->error()) {
        $self->error("dhcp: update configuration: ".
                     "file access error $filename");
        return(1);
    }
    $text = "$fh";
    $fh->close();

    #
    # Add/removal of nodes
    #
    ($error, $text) = $self->update_dhcp_config_file($text, $ntc, $ntr);
    if ($error != 0) {
        return(1);
    }

    #
    # Write the new dhcp configuration file
    #
    my $file = CAF::FileWriter->new($filename, mode => 0664, log => $this_app, backup => '.pre_aii');
    $file->print($text);
    $file->close();

    return(0);
}

# Adds the entry to dhcp
sub Configure
{
    my ($self, $config) = @_;

    my $tree = $config->getElement("/system/network")->getTree();
    my $fqdn = $tree->{hostname} . "." . $tree->{domainname};
    # Find the bootable interface
    my $cards = $config->getElement("/hardware/cards/nic")->getTree();
    my $bootable = undef;
    foreach my $card (keys %$cards) {
        if ($cards->{$card}->{boot}) {
            $bootable = $card;
            last;
        }
    }
    if (!$bootable) {
        $self->debug(2, "aii-dhcp: ignoring $fqdn since there is no bootable interface");
        return;
    }
    my $ip = $self->get_ip($bootable, $tree);

    my $server_ip = gethostbyname(hostname());
    $server_ip = inet_ntoa($server_ip) if defined($server_ip);
    if (!defined($server_ip)) {
        $self->error("aii-dhcp: failed to obtain own IP address");
        return;
    }

    my $opts = $config->getElement("/system/aii/dhcp")->getTree();
    my $tftpserver = "";
    my $filename = "";
    my $additional = "";
    if ($opts->{tftpserver}) {
        $tftpserver = $opts->{tftpserver};
    }
    if ($opts->{filename}) {
        $filename = $opts->{filename};
        $filename =~ s/BOOTSRVIP/$server_ip/;
    }
    if ($opts->{options}) {
        foreach my $k (sort keys %{$opts->{options}}) {
            $additional .= "option $k $opts->{options}->{$k};\n";
        }
    }

    my $nodeconfig = {
        FQDN       => $fqdn,
        NAME       => $tree->{hostname},
        ST_IP      => $ip,
        IP         => unpack('N', Socket::inet_aton($ip)),
        MAC        => $cards->{$bootable}->{hwaddr},
        ST_IP_TFTP => $tftpserver,
        FILENAME   => $filename,
        MORE_OPT   => $additional,
    };
    if ($this_app->option('use_fqdn')) {
        $nodeconfig->{NAME} = $fqdn;
    }

    if ($CAF::Object::NoAction) {
        $self->info ("Would run " . ref ($self) . " on $fqdn");
        return 1;
    }
    $self->update_dhcp_config([$nodeconfig], []);

    return 1;
}

# Removes the entry from dhcp
sub Unconfigure
{
    my ($self, $config) = @_;

    my $tree = $config->getElement("/system/network")->getTree();
    my $fqdn = $tree->{hostname} . "." . $tree->{domainname};
    # Find the bootable interface
    my $cards = $config->getElement("/hardware/cards/nic")->getTree();
    my $bootable = undef;
    foreach my $card (keys %$cards) {
        if ($cards->{$card}->{boot}) {
            $bootable = $card;
            last;
        }
    }
    my $ip = $self->get_ip($bootable, $tree);
    if ($CAF::Object::NoAction) {
        $self->info ("Would run " . ref ($self) . " on $fqdn");
        return 1;
    }
    my $nodeconfig = {
        FQDN => $fqdn,
        NAME => $tree->{hostname},
        IP   => $ip,
    };
    $self->update_dhcp_config([], [$nodeconfig]);
    return 1;
}

1;
