#${PMpre} AII::Shellfe${PMpost}

# This is the shellfe module for aii-shellfe

=pod

=head1 NAME

shellfe - AII local management utility.

The aii-shellfe program configures, marks for install or for local
boot the nodes given as arguments. It loads and runs any AII plug-ins
specified in the profile.

Check aii-shellfe for option documentation

=cut

use CAF::FileWriter;
use CAF::Lock qw (FORCE_IF_STALE);
use EDG::WP4::CCM::CacheManager;
use EDG::WP4::CCM::Fetch::ProfileCache qw($ERROR);
use LC::Exception qw (SUCCESS throw_error);
use CAF::Process;
use LWP::UserAgent;
use XML::Simple;
use EDG::WP4::CCM::Fetch;
use EDG::WP4::CCM::CCfg;
use File::Path qw(mkpath rmtree);
use File::Basename qw(basename);
use DB_File;
use Readonly;

our $profiles_info = undef;

use constant MODULEBASE => 'NCM::Component::';
use constant USEMODULE  => "use " . MODULEBASE;
use constant PROFILEINFO => 'profiles-info.xml';
use constant NODHCP     => 'nodhcp';
use constant NONBP      => 'nonbp';
use constant NOOSINSTALL=> 'noosinstall';
use constant OSINSTALL  => '/system/aii/osinstall';
use constant NBP        => '/system/aii/nbp';
use constant CDBURL     => 'cdburl';
use constant PREFIX     => 'profile_prefix';
use constant SUFFIX     => 'profile_format';
use constant HOSTNAME   => '/system/network/hostname';
# we're going to at least deprecate the global lock, but leaving for now just in case
use constant LOCKFILE   => '/var/lock/quattor/aii';
use constant RETRIES    => 6;
use constant TIMEOUT    => 60;
use constant PARTERR_ST => 16;
use constant COMMANDS   => qw (remove configure install boot rescue firmware livecd status);
use constant INCLUDE    => 'include';
use constant NBPDIR     => 'nbpdir';
use constant CONFIGURE  => 'Configure';
use constant INSTALLMETHOD      => 'Install';
use constant BOOTMETHOD => 'Boot';
use constant REMOVEMETHOD       => 'Unconfigure';
use constant STATUSMETHOD       => 'Status';
use constant RESCUEMETHOD       => 'Rescue';
use constant FIRMWAREMETHOD     => 'Firmware';
use constant LIVECDMETHOD       => 'Livecd';
use constant CAFILE     => 'ca_file';
use constant CADIR      => 'ca_dir';
use constant KEY        => 'key_file';
use constant CERT       => 'cert_file';

use constant HWCARDS   => '/hardware/cards/nic';
use constant DHCPCFG   => "/usr/sbin/aii-dhcp";
use constant DHCPOPTION => '/system/aii/dhcp/options';
use constant DHCPPATH  => '/system/aii/dhcp';
use constant MAC       => '--mac';

# Keep in sync with the help string of $PROTECTED_OPTION
Readonly our $PROTECTED_COMMANDS   => 'remove|configure|(re)?install';
Readonly our $PROTECTED_OPTION   => 'confirm';

use parent qw (CAF::Application CAF::Reporter);

our $ec = LC::Exception::Context->new->will_store_errors;

# List of options for this application.
sub app_options
{

    push(my @array,

       { NAME    => 'configure=s',
         HELP    => 'Node(s) to be configured (can be a regexp)',
         DEFAULT => undef },

       { NAME    => 'configurelist=s',
         HELP    => 'File with the nodes to be configured',
         DEFAULT => undef },

       { NAME    => 'remove=s',
         HELP    => 'Node(s) to be removed (can be a regexp)',
         DEFAULT => undef },

       { NAME    => 'removelist=s',
         HELP    => 'File with the nodes to be removed',
         DEFAULT => undef },

       { NAME    => 'removeall',
         HELP    => 'Remove ALL nodes configured',
         DEFAULT => undef },

       { NAME    => 'reinstall=s',
         HELP    => 'Node(s) to be removed, (re)configured and (re)installed (can be a regexp)',
         DEFAULT => undef },

       { NAME    => 'boot=s',
         HELP    => 'Node(s) to boot from local disk (can be a regexp)',
         DEFAULT => undef },

       { NAME    => 'bootlist=s',
         HELP    => 'File with the nodes to boot from local disk',
         DEFAULT => undef },

       { NAME    => 'install=s',
         HELP    => 'Nodes(s) to be installed (can be regexp)',
         DEFAULT => undef },

       { NAME    => 'installlist=s',
         HELP    => 'File with the nodes to be installed',
         DEFAULT => undef },

       { NAME    => 'rescue=s',
         HELP    => 'Node(s) to be booted in rescue mode',
         DEFAULT => undef },

       { NAME    => 'rescuelist=s',
         HELP    => 'File with the nodes to be booted in rescue mode',
         DEFAULT => undef },

       { NAME    => 'include=s',
         HELP    => 'Directories to add to include path',
         DEFAULT => '' },

       { NAME    => 'status=s',
         HELP    => 'Report current boot/install status for the node ' .
         '(can be a regexp)',
         DEFAULT => undef },

       { NAME    => 'statuslist=s',
         HELP    => 'File with the nodes to report boot/install status',
         DEFAULT => undef },

       { NAME    => 'firmware=s',
         HELP    => 'Nodes(s) to have their firmware image updated ' .
                     '(can be a regexp)',
         DEFAULT => undef },

       { NAME    => 'firmwarelist=s',
         HELP    => 'File with the nodes requiring firmware upgrade',
         DEFAULT => undef },

       { NAME    => 'livecd=s',
         HELP    => 'Node(s) to boot to a livecd target ' .
                    '(can be a regexp)',
         DEFAULT => undef },

       { NAME    => 'livecdlist=s',
         HELP    => 'File with the nodes requiring livecd target',
         DEFAULT => undef },

       { NAME    => CDBURL.'=s',
         HELP    => 'URL for CDB location',
         DEFAULT => undef },

       { NAME    => 'localnclcache=s',
         HELP    => 'Local cache for NCL library',
         DEFAULT => '/usr/lib/aii/aii_ncl_cache' },

       { NAME    => 'file=s',
         HELP    => 'File with the nodes and the actions to perform',
         DEFAULT => undef },

         # aii-* parameters

       { NAME    => 'nodiscovery|nodhcp',
         HELP    => 'Do not update discovery (e.g. dhcp) configuration',
         DEFAULT => undef },

       { NAME    => 'nonbp',
         HELP    => 'Do not update Network Boot Protocol (e.g. pxe) configuration',
         DEFAULT => undef },

       { NAME    => 'noosinstall',
         HELP    => 'Do not update OS installer (e.g. kickstart) configuration',
         DEFAULT => undef },

       { NAME    => "$PROTECTED_OPTION=s",
         HELP    => 'required when removing/configuring/(re)installing protected nodes otherwise the operation will fail. A node is protected when /system/aii/protected is set, and the value of that path must be passed to this parameter. Consequently only those protected nodes with same confirmation can be modified in a single shellfe command invocation.',
         DEFAULT => undef },

         # other common options

       { NAME    => 'cfgfile=s',
         HELP    => 'configuration file for aii-shellfe defaults',
         DEFAULT => '/etc/aii/aii-shellfe.conf' },

       { NAME    => 'logfile=s',
         HELP    => 'Path to the log file',
         DEFAULT => '/var/log/aii-shellfe.log' },

       { NAME    => 'noaction',
         HELP    => 'do not actually perform operations',
         DEFAULT => undef },

       { NAME    => 'use_fqdn',
         HELP    => 'Use the fully qualified domain name in the profile name (if specified). Enable it if you use a regular expression with a dot as "host name"',
         DEFAULT => undef },

       { NAME    => 'profile_prefix=s',
         HELP    => 'Default prefix for the profile name',
         DEFAULT => undef },

       { NAME    => 'profile_format=s',
         HELP    => 'Format the profile is encoded in',
         DEFAULT => 'xml' },

       { NAME    => 'cachedir=s',
         HELP    => 'where to cache foreign profiles',
         DEFAULT => "/tmp/aii" },

       { NAME    => 'lockdir=s',
         HELP    => 'where to store lock files',
         DEFAULT => "/var/lock/quattor" },

         # Options for osinstall plug-ins
       { NAME    => 'osinstalldir=s',
         HELP    => 'Directory where Kickstart files will be installed',
         DEFAULT => '/osinstall/ks' },

         # Options for DISCOVERY plug-ins
         { NAME => 'dhcpconf=s',
           HELP => 'name of dhcp configuration file',
           DEFAULT => '/etc/dhcpd.conf' },

         { NAME => 'restartcmd=s',
           HELP => 'how to restart the dhcp daemon',
           DEFAULT => 'service dhcpd restart' },

         # Options for NBP plug-ins
       { NAME    => 'nbpdir=s',
         HELP    => 'Directory where files for NBP should be stored',
         DEFAULT => '/osinstall/nbp/pxelinux.cfg' },

       { NAME    => 'bootconfig=s',
         HELP    => 'Generic "boot from local disk" file',
         DEFAULT => 'localboot.cfg' },

       { NAME   => 'rescueconfig=s',
         HELP   => 'Generic "boot from rescue image" file',
         DEFAULT        => 'rescue.cfg' },
         # Options for HTTPS
       { NAME   => CAFILE.'=s',
         HELP   => 'Certificate file for the CA' },

       { NAME   => CADIR.'=s',
         HELP   => 'Directory where allCA certificates can be found' },

       { NAME   => KEY.'=s',
         HELP   => 'Private key for the certificate' },

       { NAME   => CERT.'=s',
         HELP   => 'Certificate file to be used' },

       { NAME => "template-path=s",
         HELP => 'store for Template Toolkit files',
         DEFAULT => '/usr/share/templates/quattor'
        },

         # options inherited from CAF
         #   --help
         #   --version
         #   --verbose
         #   --debug
         #   --quiet

        );

    return(\@array);

}

# Initializes the application object. Creates the lock and locks the
# application.
sub _initialize
{
    my $self = shift;

    $self->{VERSION} = '2.0';
    $self->{USAGE} = "Usage: $0 [options]\n";

    $self->{LOG_APPEND} = 1;
    $self->{LOG_TSTAMP} = 1;
    $self->{status} = 0;
    $self->SUPER::_initialize (@_) or return undef;
    $self->set_report_logfile ($self->{LOG});
    my $f;
    $ENV{HTTPS_CA_FILE} = $f if $f = $self->option (CAFILE);
    $ENV{HTTPS_CA_DIR} = $f  if $f = $self->option (CADIR);
    $ENV{HTTPS_KEY_FILE} = $f if $f = $self->option (KEY);
    $ENV{HTTPS_CERT_FILE} = $f if $f = $self->option (CERT);
    if ($self->option(INCLUDE)) {
        unshift(@INC, split(/:+/, $self->option(INCLUDE)));
    }
    return $self;
}

# Lock a node being configured, needs to be called in every method that contains
# node operations (ie configure etc)
sub lock_node
{
    my ($self, $node) = @_;
    # /var/lock could be volatile, and the default lockdir depends on it
    mkdir($self->option("lockdir"));
    my $lockfile = $self->option("lockdir") . "/$node";
    my $lock = CAF::Lock->new ($lockfile, log => $self);
    if ($lock) {
        $lock->set_lock (RETRIES, TIMEOUT, FORCE_IF_STALE) or return undef;
    } else {
        return undef;
    }
    $self->debug(3, "aii-shellfe: locked node $node");
    return $lock;
}

# Overwrite the report method to allow the KS plug-in to print
# debugging output. See CAF::Reporter (8) for more information.
sub report
{
    my $self = shift;
    my $st = join ('', @_);
    print STDOUT "$st\n" unless $SUPER::_REP_SETUP->{QUIET};
    $self->log (@_);
    return SUCCESS;
}

sub plugin_handler {
    my ($self, $plugin, $ec, $e) = @_;
    $self->error("$plugin: $e");
    $self->{status} = PARTERR_ST;
    $e->has_been_reported(1);
    return;
}

# Runs $method on the plug-in given at $path for $node. Arguments:
# $_[1]: the name of the host being configured.
# $_[2]: the PAN path of the plug-in to be run. If the path does not
# exist, nothing will be done.
# $_[3]: the method to be run.
sub run_plugin
{
    my ($self, $st, $path, $method) = @_;

    return unless $st->{configuration}->elementExists ($path);
    # This is here because CacheManager and Fetch objects may have
    # problems when they get out of scope.
    my %rm = $st->{configuration}->getElement ($path)->getHash;
    my $modulename = (keys (%rm))[0];
    if ($modulename !~ m/^[a-zA-Z_]\w+$/) {
        $self->error ("Invalid Perl identifier specified as a plug-in. ",
                      "Skipping.");
        $self->{status} = PARTERR_ST;
        return;
    }

    if (!exists $self->{plugins}->{$modulename}) {
        $self->debug (4, "Loading module $modulename");
        eval (USEMODULE .  $modulename);
        if ($@) {
            $self->error ("Couldn't load $modulename for path $path: $@");
            $self->{status} = PARTERR_ST;
            return;
        }
        $self->debug (4, "Instantiating $modulename");
        my $class = MODULEBASE.$modulename;
        my $module = eval { $class->new($modulename) };
        if ($@) {
            $self->error ("Couldn't call 'new' on $modulename: $@");
            $self->{status} = PARTERR_ST;
            return;
        }
        $self->{plugins}->{$modulename} = $module;
    }
    my $plug = $self->{plugins}->{$modulename};
    if ($plug->can($method)) {
        $self->debug (4, "Running $modulename -> $method");
        $aii_shellfev2::__EC__ = LC::Exception::Context->new;
        $aii_shellfev2::__EC__->error_handler(sub {
            $self->plugin_handler($modulename, @_);
        });

        if (!eval { $plug->$method ($st->{configuration}) }) {
            $self->error ("Failed to execute module's $modulename $method method");
            $self->{status} = PARTERR_ST;
        }
        if ($@) {
            $self->error ("Errors running module $modulename $method method: $@");
            $self->{status} = PARTERR_ST;
        }
        return;
    } else {
        $self->debug(4, "no method $method available for plugin $modulename");
    }
}

# Adds extra options to aii-dhcp configuration. This is the only part
# of the core AII that has to explicitly look at the profile's values.
# This part may be removed at a later version, when we have a proper
# DHCP plug-in or component.
sub dhcpcfg
{
    my ($self, $node, $cmd, $st, $mac) = @_;

    my @dhcpop = (DHCPCFG, MAC, $mac);
    if ("$cmd" eq CONFIGURE) {
        my $opts = $st->{configuration}->getElement (DHCPOPTION)->getTree;
        # check for tftpserver option
        push(@dhcpop,'--tftpserver',$opts->{tftpserver})
            if (exists($opts->{tftpserver}));
        # check for addoptions
        # addoptions is a single string
        push(@dhcpop,'--addoptions',$opts->{addoptions})
            if (exists($opts->{addoptions}));
        push(@dhcpop, "--$cmd", $node);
    } elsif ("$cmd" eq REMOVEMETHOD) {
        push(@dhcpop, "--remove", $node);
    }

    # Pass debug option
    if (my $dbg = $self->option('debug') ) {
        if($dbg =~ m{^(\d+)$}) {
            push(@dhcpop, '--debug', $1);
        } else {
            $self->warn("Invalid debug value $dbg passed (should be integer)");
        };
    }
    return @dhcpop;
}

# Runs aii-dhcp on the configuration object received as argument. It
# uses the MAC of the first card marked with "boot"=true.
sub dhcp
{
    my ($self, $node, $st, $cmd) = @_;

    return unless $st->{configuration}->elementExists (DHCPPATH);

    my $mac;
    my $cards = $st->{configuration}->getElement (HWCARDS)->getTree;
    foreach my $cfg (values (%$cards)) {
       if ($cfg->{boot}) {
           $cfg->{hwaddr} =~ m{^((?:[0-9a-f]{2}[-:])+(?:[0-9a-f]{2}))$}i;
           $mac = $1;
           last;
       }
    }

    my @commands = $self->dhcpcfg ($node, $cmd, $st, $mac);
    $self->debug (4, "Going to run: " .join (" ",@commands));
    my $output;
    $output = CAF::Process->new(\@commands, log => $self)->output();
    if ($?) {
       $self->error("Error when configuring $node: $output");
    } else {
        $self->debug(4, "Output: $output");
    };
    $self->debug(4, "End output");
}


sub iter_plugins
{
    my ($self, $st, $hook) = @_;
    foreach my $plug (qw(osinstall nbp discovery)) {
        my $path = "/system/aii/$plug";
        if (!$self->option("no$plug")) {
            $self->run_plugin($st, $path, $hook);
        }
    }
}


# Returns an array with the list of nodes specified in the file given
# as an argument. Arguments:
#
# $_[1]: file name containing the list of nodes. Each element of the
# list can be a regular expression!
# $_[2]: whether or not the fully qualified domain name should be used
# in the profile name.
sub filenodelist
{
    my ($self, $rx, $fqdn) = @_;

    my @nl;

    open (FH, "<$rx") or throw_error ("Couldn't open file: $rx");

    while (my $l = <FH>) {
        next if $l =~ m/^#/;
        chomp ($l);
        $self->debug (3, "Evaluating regexp $l");
        push (@nl, $self->nodelist ($l, $fqdn));
    }
    close (FH);
    $self->debug (1, "Node list: " . join ("\t", @nl));
    return @nl;
}

# Returns the list of profiles on the CDB server that match a given
# regular expression.
#
# Arguments:
# $_[1]: the regular expression.
# $_[2]: whether or not to use fully qualified domain names in the
# profiles names.
sub nodelist
{
    my ($self, $rx, $fqdn) = @_;
    # allow the nodename to be specified as either simple nodename, or
    # as filename (i.e. .xml). However, to make sure our regexes make
    # sense, we normalize to forget about the .xml for now.
    my $extension = '\.(?:xml|json)(?:\.gz)?$';
    $rx =~ s{$extension}{};
    my $prefix = $self->option (PREFIX) || '';

    if (!$profiles_info) {
        if ($self->option (CDBURL) =~ m{^dir://(.*)$} ) {
            my $dir = $1;
            $self->debug (4, "Creating profiles-info from local directory $dir");
            # Fake the XMLin structure
            $profiles_info = {profile => [map {{content => basename($_)}} grep {m/$extension/} glob ("$dir/*")]};
        } else {
            my $url = $self->option (CDBURL) . "/" . PROFILEINFO;
            my $ua = LWP::UserAgent->new;
            $self->debug (4, "Downloading profiles-info: $url");
            my $rp = $ua->get ($url);
            unless ($rp->is_success) {
                $self->error ("Couldn't download $url. Aborting ",
                              $rp->status_line());
                $self->{state} = 1;
                return;
            }

            my $xml = $rp->content;
            $self->debug (4, "Parsing XML file from $url");
            $profiles_info = XMLin ($xml, ForceArray => 1);
            throw_error ("XML error: $_") unless $profiles_info;
        };
    }

    $rx =~ m{^([^.]*)(.*)};
    $rx = $1;
    $rx .= "($2)" if $fqdn;
    my @nl;
    foreach (@{$profiles_info->{profile}}) {
        if ($_->{content} =~ m/$prefix($rx)\.(?:xml|json)\b/) {
            my $host = $1;
            $self->debug (4, "Added $host to the list");
            push (@nl, $host);
        }
    }

    $self->error ("No node matches $rx") unless (@nl);
    return @nl;
}

sub cachedir {
    my ($self, $node) = @_;
    my $basedir = $self->option("cachedir");
    my $cachedir = $basedir;
    if ($self->option('use_fqdn') and $node =~ m{\.(.*)}) {
        # break out hosts into subdirectories based on domain
        # so long as there are less than 30,000 hosts per domain,
        # this should give sufficient hashing to avoid any problems
        # with directory size.
        $cachedir .= "/$1";
    }
    $cachedir .= "/$node";
    return $cachedir;
}

# Returns a hash with the node names given as arguments as keys and
# the pair { fetch, cachemanager } objects associated to their
# profiles as values.
sub fetch_profiles
{
    my ($self, @nl) = @_;
    my %h;

    my $cdb = $self->option (CDBURL);
    my $prefix = $self->option (PREFIX) || '';
    my $suffix = $self->option (SUFFIX) || '';

    if ($suffix =~ m{^([-\w\.]*)$}) {
        $suffix = $1;
    } else {
        $self->error ("Invalid suffix for profiles. Leaving");
        $self->{status} = PARTERR_ST;
        return ();
    }

    if ($cdb =~ m{([\w\-\.+]+://[+\w\.\-%?=/:]+)}) {
        $cdb = $1;
        # All profiles from dir:// can be accessed as file://
        $cdb =~ s{^dir://}{file://};
    } else {
        $self->error ("Invalid base URL. Leaving");
        $self->{status} = PARTERR_ST;
        return ();
    }

    # Read the config of the current host
    # Certain parameters (e.g. json_typed) can have an influence on the behaviour
    # and functioning of AII (e.g. json_typed support for rendering).
    EDG::WP4::CCM::CCfg::initCfg();
    my $json_typed = EDG::WP4::CCM::CCfg::getCfgValue('json_typed');
    # Reset to the CCM::CCfg defaults, we will use an isolated config file
    # for each foreign profile
    EDG::WP4::CCM::CCfg::resetCfg();

    foreach my $node (@nl) {
        next if exists $h{$node};
        my $ccmdir = $self->cachedir($node);
        my $url = "$cdb/$prefix$node.$suffix";
        $self->debug (1, "Fetching profile: $url");

        if ((!-d $ccmdir) && !mkpath($ccmdir)) {
            $self->error("failed to create directory $ccmdir: $!");
            next;
        }
        my $config = "$ccmdir/ccm.conf";

        my $cfg_fh = CAF::FileWriter->new($config, log => $self);
        my $err = $ec->error();
        if(defined($err)) {
            $self->error("failed to create config file $config: ".$err->reason());
            next;
        } else {
            print $cfg_fh "cache_root $ccmdir\n";
            print $cfg_fh "json_typed $json_typed\n";
            print $cfg_fh "tabcompletion 0\n";

            my $changed = $cfg_fh->close() ? "" : "not";
            $self->debug(1, "config file $config $changed changed.");
        };

        # we use CDB_File, since it's the fastest
        my  $fh = EDG::WP4::CCM::Fetch->new ({PROFILE_URL => $url, FOREIGN => 1, CONFIG => $config, DBFORMAT => 'CDB_File'});
        unless ($fh) {
            $self->error ("Error creating Fetch object for $url");
            $self->{status} = PARTERR_ST;
            next;
        }

        my $res = $fh->fetchProfile();
        if (! $res || $res == $ERROR) {
            my $msg;
            if (defined($res)) {
                $msg = "something went wrong, see previous error";
            } else {
                $msg = "failed to download";
            }

            $self->error("Impossible to fetch profile for $node: $msg. Skipping.");
            next;
        }

        my $cm = EDG::WP4::CCM::CacheManager->new ($fh->{CACHE_ROOT}, $config);
        if ($cm) {
            my $cfg = $cm->getLockedConfiguration (0);
            $h{$node} = {
                fetch        => $fh,
                cachemanager => $cm,
                configuration=> $cfg,
            };
        } else {
            $self->error ("Failed to create CacheManager ",
                          "object for node $node");
            $self->{status} = PARTERR_ST;
        }
        $self->debug (1, "Inserted structure for $node on fetching structure");
    }
    return %h;
}


# Wrapper to execute the commands in sorted manner
no strict 'refs';
foreach my $cmd (COMMANDS) {
    *{$cmd} = sub {
        my ($self, %node_states) = @_;
        my $method = "_$cmd";
        foreach my $node (sort keys %node_states) {
            $self->debug (2, "$cmd: $node");
            if ($cmd ne 'status') {
                my $lock = $self->lock_node($node);
                if (! $lock) {
                    $self->error("aii-shellfe: couldn't acquire lock on $node for $cmd");
                    next;
                };
            };
            $self->$method($node, $node_states{$node});
        };
    }
}
use strict 'refs';


# Runs the Install method of the NBP plugins of the nodes given as
# arguments.
sub _install
{
    my ($self, $node, $st) = @_;
    $self->run_plugin ($st, NBP, INSTALLMETHOD);
}

# Runs the Status method of the NBP plugins of the nodes given as
# arguments.
sub _status
{
    my ($self, $node, $st) = @_;

    $self->debug (1, "Showing the state of $node");
    $self->run_plugin ($st, NBP, STATUSMETHOD);
}

# Runs the Boot method of the NBP plugins of the nodes given as
# arguments.
sub _boot
{
    my ($self, $node, $st) = @_;
    $self->run_plugin ($st, NBP, BOOTMETHOD);
}

# Runs the Firmware method of the NBP plugins of the nodes given as
# arguments.
sub _firmware
{
    my ($self, $node, $st) = @_;
    $self->run_plugin ($st, NBP, FIRMWAREMETHOD);
}

# Runs the Livecd method of the NBP plugins of the nodes given as
# arguments
sub _livecd
{
    my ($self, $node, $st) = @_;
    $self->run_plugin($st, NBP, LIVECDMETHOD);
}

# Runs the Remove method of the NBP plugins of the nodes given as
# arguments.
sub _remove
{
    my ($self, $node, $st) = @_;

    $self->iter_plugins($st, REMOVEMETHOD);

    if ($st->{reinstall}) {
        $self->debug(3, "No dhcp and cache removal with reinstall set for $node");
    } else {
        if ($st->{configuration}->elementExists("/system/aii/dhcp")) {
            $self->dhcp ($node, $st, REMOVEMETHOD) unless $self->option (NODHCP);
        }
        $self->remove_cache_node($node) unless $self->option('noaction');
    };
}

# Runs the Rescue method of the NBP plugins of the nodes given as
# arguments.
sub _rescue
{
    my ($self, $node, $st) = @_;

    $self->run_plugin ($st, NBP, RESCUEMETHOD);
}

# Configures DISCOVERY, OSINSTALL and NBP on the nodes received as
# arguments.
sub _configure
{
    my ($self, $node, $st) = @_;

    my $when = time();

    $self->iter_plugins($st, CONFIGURE);
    if ($st->{configuration}->elementExists("/system/aii/dhcp")) {
        $self->dhcp($node, $st, CONFIGURE) unless $self->option(NODHCP);
    }
    $self->set_cache_time($node, $when) unless $self->option('noaction');
}


sub get_cache_time {
    my ($self, $node) = @_;

    my $cachedir = $self->cachedir($node);
    return (stat("$cachedir/aii-configured"))[9] || 0;
}

sub set_cache_time {
    my ($self, $node, $when) = @_;
    my $cachedir = $self->cachedir($node);
    if (!open(TOUCH, ">$cachedir/aii-configured")) {
        $self->error("aii-shellfe: failed to update state for $node: $!");
    }
    close(TOUCH);
}

sub remove_cache_node {
    my ($self, $node) = @_;
    my $cachedir = $self->cachedir($node);
    rmtree($cachedir);
}

# If a host is protected, check the protectid is correct, else don't include to process further
sub check_protected {
    my ($self, %hash) = @_;
    my @to_delete;

    foreach my $host (sort(keys %hash)) {
        my $st = $hash{$host};
        my $cfg = $st->{configuration}->getTree('/system');
        if ($cfg->{aii}->{protected}){
            my $confirmation = $cfg->{aii}->{protected};
            $self->debug(1, "Parsing protected host $host");
            my $cmdline_confirmation = $self->option($PROTECTED_OPTION);
            if (!$cmdline_confirmation) {
                $self->error("Host $host is protected. Specify --$PROTECTED_OPTION $confirmation to overwrite.");
                push(@to_delete, $host);
            } elsif ($confirmation ne $cmdline_confirmation) {
                $self->error("Host $host is protected and wrong confirmation specified. Specify --$PROTECTED_OPTION $confirmation to overwrite.");
                push(@to_delete, $host);
            } else {
                $self->debug(1, "Protected host $host confirm id ok");
            }
        }
    }
    delete @hash{@to_delete};

    return %hash;
}

# Runs all the commands
sub cmds
{
    my $self = shift;

    my $filecmds = {};
    my $file = $self->option("file");
    if ($file) {
        my @content = ();
        if ($file eq '-') {
            @content = <>;
        } else {
            if (!open(FILE, $file)) {
                $self->error("cannot open $file: $!");
                return 0;
            }
            @content = <FILE>;
            close(FILE);
        }
        foreach my $line (@content) {
            chomp($line);
            $line =~ s{#.*}{};
            next if (!$line || $line =~ m{^\s*$});
            my ($host, $cmd, $arg) = split(/,/, $line, 3);
            $filecmds->{$cmd} ||= {};
            $filecmds->{$cmd}->{$host} = $arg;
        }

        foreach my $host (sort keys %{$filecmds->{reinstall}}) {
            $self->info("File reinstall option for host $host (setting remove, configure and install)");
            foreach my $cmd (qw(remove configure install)) {
                $filecmds->{$cmd}->{$host} = $filecmds->{reinstall}->{$host};
            }
        }
    }

    foreach my $cmd (COMMANDS) {
        my $rx;
        my @nodelist = ();
        my @reinstall_list = (); # Kept in seperate list to set reinstall bit

        if ($cmd =~ m/^(remove|configure|install)$/ &&
            $self->option ("reinstall")) {
            $self->info("$cmd step for reinstall option.");

            @reinstall_list = $self->nodelist ($rx, $self->option ('use_fqdn'))
                if ($rx = $self->option ('reinstall'));
            push(@nodelist, @reinstall_list);
        }

        @nodelist = $self->nodelist ($rx, $self->option ('use_fqdn'))
            if ($rx = $self->option ($cmd));

        if (exists $filecmds->{$cmd}) {
            push(@nodelist, sort keys %{$filecmds->{$cmd}});
        }
        $self->debug (2, "Nodes for $cmd: ", join (", ", @nodelist));

        push (@nodelist, $self->filenodelist ($rx, $self->option ('use_fqdn')))
            if ($rx = $self->option ($cmd."list"));
        $self->debug (2, $cmd."list: ", join (", ", @nodelist));

        if (@nodelist) {
            my %nodes = $self->fetch_profiles (@nodelist);

            if ($cmd =~ m/^($PROTECTED_COMMANDS)$/) {
                %nodes = $self->check_protected(%nodes);
                if (!(%nodes)) {
                    $self->error('No nodes left to process after checking for protected hosts');
                    return ;
                }
            }
            # Set the reinstall bit
            foreach my $node (@reinstall_list) {
                $nodes{$node}->{reinstall} = 1 if exists($nodes{$node});
            }

            $self->$cmd (%nodes);
            $self->info (scalar (keys (%nodes)) . " nodes to $cmd");
        }
    }

}

sub finish {
    my ($self) = @_;
    $self->debug(5, "closing down");
    foreach my $plugin (keys %{$self->{plugins}}) {
        if ($self->{plugins}->{$plugin}->can("finish")) {
            $self->debug(5, "invoking finish for $plugin");
            $self->{plugins}->{$plugin}->finish();
        }
    }
}

1;
