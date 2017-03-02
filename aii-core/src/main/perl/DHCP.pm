#${PMpre} AII::DHCP${PMpost}

use parent qw (CAF::Application CAF::Reporter);

use Socket;

use LC::Exception qw (SUCCESS);

use CAF::Process;
use CAF::FileReader;
use CAF::FileWriter;
use CAF::Lock qw (FORCE_IF_STALE);

our $EC = LC::Exception::Context->new->will_store_all;

# locking configuration
use constant TIMEOUT => 60;
use constant RETRIES => 6;


sub app_options {

    # these options complement the ones defined in CAF::Application
    push(my @array,

        # aii-dhcp specific options

        { NAME    => 'configure=s',
          HELP    => 'Node to be configured (needs MAC address)',
          DEFAULT => undef },

        { NAME    => 'configurelist=s',
          HELP    => 'File with the list of nodes to be configured',
          DEFAULT => undef },

        { NAME    => 'mac=s',
          HELP    => 'MAC address of the node (mandatory with --configure)',
          DEFAULT => undef },

        { NAME    => 'tftpserver=s',
          HELP    => 'TFTP server (optional with --configure)',
          DEFAULT => undef },

        { NAME    => 'addoptions=s',
          HELP    => 'Additional parameters (optional with --configure)',
          DEFAULT => undef },

        { NAME    => 'remove=s',
          HELP    => 'Node to be removed',
          DEFAULT => undef },

        { NAME    => 'removelist=s',
          HELP    => 'File with the list of nodes to be removed',
          DEFAULT => undef },

        # options for DHCP configuration

        { NAME    => 'dhcpconf=s',
          HELP    => 'DHCP server configuration file',
          DEFAULT => '/etc/dhcpd.conf' },

        { NAME    => 'restartcmd=s',
          HELP    => 'Command to restart the DHCP server',
          DEFAULT => '/sbin/service dhcpd restart' },

        { NAME    => 'norestart',
          HELP    => 'Do not restart the DHCP server',
          DEFAULT => undef },

        # other common options

        { NAME    => 'logfile=s',
          HELP    => 'path/filename to use for program logs',
          DEFAULT => "/var/log/aii-dhcp.log" },

        { NAME    => 'cfgfile=s',
          HELP    => 'Configuration file',
          DEFAULT => '/etc/aii/aii-dhcp.conf' }

        # options inherited from CAF
        #   --help
        #   --version
        #   --verbose
        #   --debug
        #   --quiet

        );

    return(\@array);
}

sub _initialize {

    my $self = shift;

    # define application specific data.

    # external version number
    $self->{'VERSION'} = '${project.version}';

    # show setup text
    $self->{'USAGE'} = "Usage: aii-dhcp [options]\n";

    # log file policies

    # append to logfile, do not truncate
    $self->{'LOG_APPEND'} = 1;

    # add time stamp before every entry in log
    $self->{'LOG_TSTAMP'} = 1;

    $self->{NTC} = [];
    $self->{NTR} = [];

    # start initialization of CAF::Application
    unless ($self->SUPER::_initialize(@_)) {
        return;
    }
    # start using log file (could be done later on instead)
    $self->set_report_logfile($self->{'LOG'});

    return(SUCCESS);

}

# restart_daemon(cmd)
#
# restart dhcp daemon using arrayref cmd
# Return 1 on failure, 0 on success.
sub restart_daemon
{
    my ($self, $cmd) = @_;

    $self->debug(3, "AII::DHCP: restarting daemon dhcpd");

    my $output = CAF::Process->new($cmd, log => $self)->output();
    if ($?) {
        $self->error("AII::DHCP: error restarting dhcp daemon: $output");
        return(1);
    } else {
        $self->verbose("AII::DHCP: daemon restarted: $output");
    }

    return(0);
}

# update_dhcp_config_file($text)
#
# Remove and add host declarations from resp NTR and NTC
# Returns tuple with first element succes(=0) or failure (=1),
# 2nd element the new text (or empty in case of failure).
sub update_dhcp_config_file
{

    my ($self, $text) = @_;

    my $node;

    # Remove existing nodes (both NodesToConfigure and NodesToRemove)
    my $nodes_regexp = '';
    foreach $node (@{$self->{NTC}}, @{$self->{NTR}}) {
        $nodes_regexp .= $node->{NAME} . '|' . $node->{FQDN} . '|';
    }
    $nodes_regexp =~ s/\|$//; # remove last '|'

    # primitive support for if {} else {} parameters host group
    # only starting from perl 5.10 can you use recursive regexp
    # for recursive examples, see http://www.perlmonks.org/?node_id=547596 or
    # http://stackoverflow.com/questions/133601/can-regular-expressions-be-used-to-match-nested-patterns
    $nodes_regexp = '\\n\s*host\s+(' . $nodes_regexp . ')\s*\{[^{}]*(?:\{[^{}]*\}(?:[^{}]*\{[^{}]*\})?|[^{}]*)[^{}]*\}';

    # Remove all to be configured and to be removed
    $text =~ s/$nodes_regexp//gm;

    # Collect the subnets + netmask definitions
    my @netandmasks = ($text =~ /\n\s*subnet\s+([\d\.]+)\s+netmask\s+([\d\.]+)/g);

    if ($#netandmasks % 2 == 0) {
        $self->error("AII::DHCP: syntax error on dhcpd config file: " .
                     "netmask/network missing in subnet declaration");
        return(1, '');
    }

    my (@subnets, $i);
    for ($i=0 ; $i<$#netandmasks ; $i=$i+2) {
        push (@subnets, {
                NET     => unpack('N', Socket::inet_aton($netandmasks[$i])),
                MASK    => unpack('N', Socket::inet_aton($netandmasks[$i+1])),
                ST_NET  => $netandmasks[$i],
                ST_MASK => $netandmasks[$i+1],
              });
        $self->verbose("AII::DHCP: found subnet $netandmasks[$i] " .
                       "mask $netandmasks[$i+1]");
    }

    # If subnets are not defined in the DHCP configuration file managed by AII,
    # just add an empty subnet. This will have the effect of disabling all the checks
    # related to subnets.
    my $subnet_defined = 1;
    my $indent = " " x 2;
    if ( @subnets == 0 ) {
        push (@subnets, {});
        $subnet_defined = 0;
        $indent = "";
    }

    # for each subnet, write entries that belong to it
    foreach my $net (@subnets) {
        my $newnodes = '';

        foreach $node (@{$self->{NTC}}) {

            # Does the node belong to this subnet?
            # Always true if no subnet defined.
            if ( !$subnet_defined || (($node->{IP} & $net->{MASK}) == $net->{NET}) ) {

                $node->{OK} = 1;

                # basic host declaration
                $newnodes .= "\n".$indent."host $node->{NAME} {  # added by aii-dhcp\n";

                foreach my $mac (split(' ', $node->{MAC})) {
                    $newnodes .= "$indent  hardware ethernet $mac;\n";
                }

                $newnodes .= "$indent  fixed-address $node->{ST_IP};\n";

                # TFTP server
                if ($node->{ST_IP_TFTP}) {
                    $newnodes .= "$indent  next-server $node->{ST_IP_TFTP};\n";
                }

                # additional options
                if ($node->{MORE_OPT}) {
                    $newnodes .= "$indent  $node->{MORE_OPT}\n";
                }

                $newnodes .= "$indent}\n";
                if ( $subnet_defined ) {
                    $self->verbose("AII::DHCP: added node $node->{NAME} ".
                                       "to subnet $net->{ST_NET}");
                } else {
                    $self->verbose("AII::DHCP: added node $node->{NAME} (no subnet specified)");
                }
            }

        }

        # Insert the nodes in the current subnet
        if ($newnodes ne '') {
            $self->debug(1, "AII::DHCP: newnodes=|$newnodes|\n");
            if ( $subnet_defined ) {
                $text =~ s/( \s*  subnet  \s+ \Q$net->{ST_NET}\E  \s+
                         netmask \s+ \Q$net->{ST_MASK}\E \s+ \{
                         ([^{}]+\{[^{}]+\})*)
                         ([^}]+)(\})/$1$3$newnodes$4/x;
            } else {
                $text .= $newnodes;
            };
        }
    }

    # Just a stupid check for nodes not inserted
    foreach $node (@{$self->{NTC}}) {
        ($node->{OK}) || $self->warn("dhcp: No valid subnet found " .
                                     "for $node->{FQDN}");
    }

    return (0, $text);

}


# update_dhcp_config(filename)
#
# Update DHCP configuration file
# Return tuple with first element 1 on failure, 0 on success;
# 2nd element boolean if configuration file changed
sub update_dhcp_config
{
    my ($self, $filename) = @_;


    # Lock and load the current dhcp configuration file
    my $lockfile = $filename . ".lock";
    my $lock = CAF::Lock->new ($lockfile, log => $self);
    unless ($lock && $lock->set_lock (RETRIES, TIMEOUT, FORCE_IF_STALE)) {
        $self->error("dhcp: couldn't acquire lock on $lockfile");
        return(1, 0);
    }
    $self->debug(3, "Locked dhcp configuration");

    $self->debug(3, "DHCP configuration file : $filename");
    my $fh = CAF::FileReader->new($filename, log => $self);
    if ($EC->error()) {
        $self->error("dhcp: update configuration: read dhcp config $filename: ".$EC->error()->reason());
        $EC->ignore_error();
        return (1, 0);
    }

    # Add/removal of nodes
    my ($error, $text) = $self->update_dhcp_config_file("$fh");
    return (1, 0) if $error;

    # Write the new dhcp configuration file
    $fh = CAF::FileWriter->new($filename, backup => '.pre_aii', log => $self);
    print $fh $text;
    my $changed = $fh->close();

    if ($EC->error()) {
        $self->error("dhcp: Error creating dhcp config $filename: ".$EC->error()->reason());
        $EC->ignore_error();
        return (1, $changed);
    }

    return(0, $changed);
}

# new_remove_entry($host)
# Check and add a node to the array NTR (nodes to remove)
# Return 1 on failure, 0 on success
sub new_remove_entry
{

    my ($self, $host) = @_;

    # Check host
    if (!defined($host) || $host eq '') {
        $self->warn('AII::DHCP: missing hostname');
        return(1);
    }

    my ($fqdn, @all_address) = (gethostbyname($host))[0,4];
    if (! @all_address) {
        # The array is empty => invalid name
        $self->warn("AII::DHCP: invalid hostname to remove ($host), DNS lookup failed");
        return(1);
    }

    # add entry to NodesToRemove array
    my $ip = Socket::inet_ntoa($all_address[0]);
    push(@{$self->{NTR}}, {
            FQDN => $fqdn,
            NAME => $fqdn, # TODO: used to have $host = $fqdn above, but messes up debug message below
            IP   => $ip,
         } );

    $self->debug(2, "AII::DHCP: mark $host (fqdn: $fqdn, ip: $ip) to remove");

    return(0);
}

# new_configure_entry($host, $mac, [$tftpserver, @params])
#
# Check and add a node to the array NTC (nodes to configure)
sub new_configure_entry
{

    my ($self, $host, $mac, $tftpserver, @additional) = @_;

    # Check hostname
    if (!defined($host) || $host eq '') {
        $self->warn('AII::DHCP: missing hostname');
        return(1);
    }

    my ($fqdn, @all_address) = (gethostbyname($host))[0,4];
    if ($#all_address < 0) {        # The array is empty => invalid name
        $self->warn("AII::DHCP: invalid hostname to add ($host)");
        return(1);
    }

    # Check MAC address
    if (!defined($mac)) {
        $self->warn("AII::DHCP: missing MAC address for host $host");
        return(1);
    }

    if ($mac !~ /^([[:xdigit:]]{2}[\:\-]){5}[[:xdigit:]]{2}$/) {
        $self->warn("AII::DHCP: MAC address $mac not valid for host $host");
        return(1);
    }

    # Check TFTP server
    #
    # special case: input from file, there are additional options defined
    # but no tftpserver => in the text file tftpserver should be ';'
    if ($tftpserver && $tftpserver ne ';') {
        my @all_tftp_address = (gethostbyname($tftpserver))[4];
        if (@all_tftp_address) {
            # Get the IP address
            $tftpserver = Socket::inet_ntoa($all_tftp_address[0]);
        } else {
            # The array is empty => invalid name
            $self->warn("AII::DHCP: invalid TFTP server ($tftpserver) for $host: DNS lookup failed");
            return(1);
        }
    }

    # IP in dotted form
    my $ip = Socket::inet_ntoa($all_address[0]);

    # check if the host entry already exists
    foreach my $item (@{$self->{NTC}}) {
        if($item->{FQDN} eq $fqdn) {
            $self->debug(2, "AII::DHCP: new MAC entry for existing host = $host fqdn = $fqdn mac = $mac");
            $item->{MAC} .= " $mac";
            $mac = ""; # flag meaning object found
            last;
        }
    }

    if ($mac ne "") {    # it was a new host entry
        my $add_txt = join(' ', @additional);
        push(@{$self->{NTC}}, {
                FQDN       => $fqdn,
                NAME       => $fqdn, # TODO: used to have $host = $fqdn above, messes up debug messages
                ST_IP      => Socket::inet_ntoa($all_address[0]),
                IP         => unpack('N', $all_address[0]),
                MAC        => $mac,
                ST_IP_TFTP => $tftpserver,
                MORE_OPT   => $add_txt,
             } );
        $self->debug(2, "AII::DHCP: add new entry: host = $host fqdn = $fqdn mac = $mac");
        $self->debug(3, "AII::DHCP: add new entry: host = $host additional opts: $add_txt");
    }

    return(0);
}

# read_input()
#
# Read from command line and/or file lists the hostnames involved
# and save them in NTC (NodesToConfigure) or in NTR (NodesToRemove)
#
# Return true in case of any error
sub read_input
{
    my $self = shift;

    my $error = 0;

    # add one entry (from command line)
    if ($self->option('configure')) {
        $error += $self->new_configure_entry(
            $self->option('configure'),
            $self->option('mac'),
            $self->option('tftpserver'),
            $self->option('addoptions'),
            );
    }

    # remove one entry (from command line)
    if ($self->option('remove')) {
        $error += $self->new_remove_entry($self->option('remove'));
    }

    # add more than one entries (from a text file)
    my $filename = $self->option('configurelist');
    if ($filename) {
        # get input data
        my $fh = CAF::FileReader->new($filename, log => $self);
        if ($EC->error()) {
            $self->error("AII::DHCP: configurelist error: file access error $filename");
            $error +=1;
        } else {
            $self->debug(2, "AII::DHCP: reading nodes to configure from file: $filename");
            foreach my $item (split(m/\n/, "$fh")) {
                if ($item =~ m/^\s*([^#].*?)\s*$/) {
                    $error += $self->new_configure_entry(split(m/\s+/, $1));
                }
            }
        }
    }

    # Remove some entries (from a text file)
    $filename = $self->option('removelist');
    if ($filename) {

        my $fh = CAF::FileReader->new($filename, log => $self);
        if ($EC->error()) {
            $self->error("AII::DHCP: removelist error: file access error $filename");
            $error +=1;
        } else {
            $self->debug(2, "AII::DHCP: reading nodes to remove from file: $filename");
            foreach my $item (split(m/\n/, "$fh")) {
                if ($item =~ m/^\s*([^#].*?)\s*$/) {
                    $error += $self->new_remove_entry($1);
                }
            }
        }
    }

    return $error;
}

# update the dhcp config file and restart daemon
sub update_and_restart
{
    my $self = shift;

    my $filename = $self->option('dhcpconf');
    $self->debug(1, "AII::DHCP: going to update dhcpd configuration $filename if needed");
    my ($error, $changed) = $self->update_dhcp_config($filename);
    if ($error) {
        $self->error("AII::DHCP: failed to update dhcpd configuration $filename");
        return;
    }

    # restart dhcpd daemon
    if ($changed) {
        if ($self->option('norestart')) {
            $self->verbose("AII::DHCP: config $filename changed but norestart set!");
        } else {
            my $cmd = $self->option('restartcmd');
            $self->info("AII::DHCP: config $filename changed, restarting dhcpd daemon using cmd '$cmd'");
            # expects an arayref
            $self->restart_daemon([split(/\s+/, $cmd)]);
        }
    } else {
        $self->verbose("AII::DHCP: no changes to $filename: daemon not restarted");
    }
    return 1;
}

# return true if nodes need to be configured or removed
sub nodes_to_change
{
    my $self = shift;
    return  return (@{$self->{NTC}} + @{$self->{NTR}}) ? 1 : 0;
}

# update dhcpd configuration file
sub configure_dhcp
{
    my $self = shift;
    if ($self->nodes_to_change()) {
        $self->info('DHCP will be updated and restarted if needed');
        return 0 if (!$self->update_and_restart());
    } else {
        $self->debug(1, "AII:DHCP: DHCP up to date, no nodes to configure");
    }
    return 1;
}

# return 1 on failure, 0 on success
sub configure
{
    my $self = shift;

    # process command line options
    $self->debug(1, "AII::DHCP: reading cmd line or input files");
    if ($self->read_input()) {
        $self->error("AII::DHCP: failed to process cmd line or input files");
        return(1);
    }
    return 1 if (!$self->configure_dhcp());

    return 0;
}

1;
