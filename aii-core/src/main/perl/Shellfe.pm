#${PMpre} AII::Shellfe${PMpost}

# This is the shellfe module for aii-shellfe

=pod

=head1 NAME

shellfe - AII local management utility.

The aii-shellfe program configures, marks for install or for local
boot the nodes given as arguments. It loads and runs any AII plug-ins
specified in the profile.

Check aii-shellfe for option documentation

=head1 FUNCTIONS

=over

=cut

use CAF::FileWriter;
use CAF::FileReader;
use CAF::Lock qw (FORCE_IF_STALE);
use EDG::WP4::CCM::CacheManager;
use EDG::WP4::CCM::Fetch::ProfileCache qw($ERROR);
use LC::Exception qw (SUCCESS throw_error);
use CAF::Process;
use CAF::Download::LWP;
use XML::Simple;
use EDG::WP4::CCM::Fetch;
use EDG::WP4::CCM::CCfg;
use File::Path qw(mkpath rmtree);
use File::Basename qw(basename dirname);
use DB_File;
use Readonly;
use Parallel::ForkManager 0.7.6;

use NCM::Component::metaconfig 18.6.0;

our $profiles_info = undef;
use AII::DHCP;
use NCM::Component::PXELINUX::constants qw(:pxe_constants);
use 5.10.1;

use constant MODULEBASE => 'NCM::Component::';
use constant USEMODULE  => "use " . MODULEBASE;
use constant PROFILEINFO => 'profiles-info.xml';

use constant NODHCP     => 'nodhcp';
use constant DISCOVERY  => '/system/aii/discovery';
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
use constant COMMANDS   => qw (remove configure install boot rescue firmware livecd status metaconfig);
use constant INCLUDE    => 'include';
use constant CAFILE     => 'ca_file';
use constant CADIR      => 'ca_dir';
use constant KEY        => 'key_file';
use constant CERT       => 'cert_file';
use constant HWCARDS    => '/hardware/cards/nic';
use constant DHCPCFG    => "/usr/sbin/aii-dhcp";
use constant DHCPOPTION => '/system/aii/dhcp/options';
use constant DHCPPATH   => '/system/aii/dhcp';
use constant MAC        => '--mac';

# Actual method associated with various actions
use constant CONFIGURE       => 'Configure';
use constant INSTALLMETHOD   => 'Install';
use constant BOOTMETHOD      => 'Boot';
use constant REMOVEMETHOD    => 'Unconfigure';
use constant STATUSMETHOD    => 'Status';
use constant RESCUEMETHOD    => 'Rescue';
use constant FIRMWAREMETHOD  => 'Firmware';
use constant LIVECDMETHOD    => 'Livecd';

# Keep in sync with the help string of $PROTECTED_OPTION
Readonly our $PROTECTED_COMMANDS => 'remove|configure|(re)?install';
Readonly our $PROTECTED_OPTION   => 'confirm';

# Keep this list in sync with the options list (to support no<pluginname>)
# this is also the order in which the plugins run (in iter_plugins)
# TODO: no dhcp? (but there's a nodhcp option)
Readonly::Array my @PLUGIN_NAMES => qw(osinstall nbp discovery);

Readonly my $STATE_FILENAME => 'aii-configured';

use parent qw (CAF::Application CAF::Reporter);

our $ec = LC::Exception::Context->new->will_store_errors;

=item app_options

List of options for this application (extends L<CAF::Application> default list).

=cut

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

       { NAME    => INCLUDE.'=s',
         HELP    => 'Directories to add to include path (: delimited list)',
         DEFAULT => '' },

       { NAME    => 'status=s',
         HELP    => 'Report current boot/install status for the node (can be a regexp)',
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

       { NAME    => 'metaconfig=s',
         HELP    => 'Node(s) to generate all metaconfig services for, ' .
                    'relative to the cachemanager cachepath for that host' .
                    '(can be a regexp)',
         DEFAULT => undef },

       { NAME    => CDBURL.'=s',
         HELP    => 'URL for CDB location',
         DEFAULT => undef },

       { NAME    => 'file=s',
         HELP    => 'File with the nodes and the actions to perform',
         DEFAULT => undef },

       # aii-* parameters

       # disable plugins
       { NAME    => 'nodiscovery',
         HELP    => 'Do not update discovery configuration via discovery plugin',
         DEFAULT => undef },

       { NAME    => 'nonbp',
         HELP    => 'Do not update Network Boot Protocol (e.g. pxe) configuration via nbp plugin',
         DEFAULT => undef },

       { NAME    => 'noosinstall',
         HELP    => 'Do not update OS installer (e.g. kickstart) configuration via osinstall plugin',
         DEFAULT => undef },

       { NAME    => "$PROTECTED_OPTION=s",
         HELP    => 'required when removing/configuring/(re)installing protected nodes otherwise ' .
                    'the operation will fail. A node is protected when /system/aii/protected is set, ' .
                    'and the value of that path must be passed to this parameter. Consequently only ' .
                    'those protected nodes with same confirmation can be modified in a single shellfe '.
                    'command invocation.',
         DEFAULT => undef },

       # DHCP option, not a plugin
       { NAME    => NODHCP,
         HELP    => 'Do not update DHCP configuration',
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
         HELP    => 'Use the fully qualified domain name in the profile name (if specified). Enable it if you ' .
                    'use a regular expression with a dot as "host name"',
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

       { NAME    => 'parallel=i',
         HELP    => 'run commands on hosts in parallel ',
         DEFAULT => 0 },

       { NAME    => 'logpid',
         HELP    => "Add process ID to the log messages (disabled by default, unless parallel is > 1)",
         DEFAULT => undef },

       # Options for osinstall plug-ins
       { NAME    => 'osinstalldir=s',
         HELP    => 'Directory where Kickstart files will be installed',
         DEFAULT => '/osinstall/ks' },

       # Options for DISCOVERY plug-ins
       { NAME    => 'dhcpcfg=s',
         HELP    => 'name of aii configuration file for dhcp',
         DEFAULT => '/etc/aii/aii-dhcp.conf' },

       # Options for NBP plug-ins
       { NAME    => NBPDIR_PXELINUX.'=s',
         HELP    => 'Directory where files for PXELINUX NBP should be stored',
         DEFAULT => OSINSTALL_DEF_ROOT_PATH . OSINSTALL_DEF_PXELINUX_DIR },

       # Default value for nbpdir_grub2 will be computed based on nbpdir
       { NAME    => NBPDIR_GRUB2.'=s',
         HELP    => 'Directory where files for Grub2 NBP should be stored',
         DEFAULT => undef },

       { NAME    => LOCALBOOT.'=s',
         HELP    => 'Generic "boot from local disk" file',
         DEFAULT => LOCAL_BOOT_CONFIG_FILE },

       { NAME    => GRUB2_EFI_LINUX_CMD.'=s',
         HELP    => 'Grub2 command to use for loading the kernel',
         DEFAULT => GRUB2_EFI_LINUX_CMD_DEFAULT },

       # Default value for grub2_efi_kernel_root will be computed based on nbpdir
       { NAME    => GRUB2_EFI_KERNEL_ROOT.'=s',
         HELP    => 'Parent path for the directories containing installation kernel/initrd',
         DEFAULT => undef },

       { NAME    => 'rescueconfig=s',
         HELP    => 'Generic "boot from rescue image" file',
         DEFAULT => 'rescue.cfg' },

       # Options for HTTPS
       { NAME    => CAFILE.'=s',
         HELP    => 'Certificate file for the CA' },

       { NAME    => CADIR.'=s',
         HELP    => 'Directory where allCA certificates can be found' },

       { NAME    => KEY.'=s',
         HELP    => 'Private key for the certificate' },

       { NAME    => CERT.'=s',
         HELP    => 'Certificate file to be used' },

       { NAME => "template-path=s",
         HELP => 'store for Template Toolkit files',
         DEFAULT => '/usr/share/templates/quattor' },

       );

    return(\@array);

}

=item _initialize

Initializes the application object. Creates the lock and locks the
application.

=cut

sub _initialize
{
    my $self = shift;

    $self->{VERSION} = '2.0';
    $self->{USAGE} = "Usage: $0 [options]\n";

    $self->{LOG_APPEND} = 1;
    $self->{LOG_TSTAMP} = 1;
    $self->{status} = 0;

    $self->SUPER::_initialize (@_) or return undef;

    # Defaults: append to logfile, add timestamp
    my $logopts = 'at';
    if ((!defined($self->option('logpid')) && ($self->option('parallel') > 1)) || $self->option('logpid'))  {
        $logopts .= 'p';
    }
    return if(! $self->init_logfile($self->option("logfile"), $logopts));


    # Log all warnings
    $SIG{__WARN__} = sub {
        $self->verbose("Perl warning: $_[0]");
    };

    if ($self->option(INCLUDE)) {
        unshift(@INC, split(/:+/, $self->option(INCLUDE)));
    }

    # Initialization and validation of some options whose default values are based on other options
    if ( $self->option(NBPDIR_PXELINUX) ) {
        $self->{CONFIG}->set(NBPDIR_PXELINUX, undef) if $self->option(NBPDIR_PXELINUX) eq NBPDIR_VARIANT_DISABLED;
    }
    if ( $self->option(NBPDIR_GRUB2) ) {
        $self->{CONFIG}->set(NBPDIR_GRUB2, undef) if $self->option(NBPDIR_GRUB2) eq NBPDIR_VARIANT_DISABLED;
    } else {
        if ( $self->option(NBPDIR_PXELINUX) ) {
            my $efi_dir = dirname($self->option(NBPDIR_PXELINUX)) . OSINSTALL_DEF_GRUB2_DIR;
            $self->{CONFIG}->set(NBPDIR_GRUB2, $efi_dir);
        } else {
            $self->{CONFIG}->set(NBPDIR_GRUB2, OSINSTALL_DEF_ROOT_PATH . OSINSTALL_DEF_GRUB2_DIR);
        }
    }
    if ( !$self->option(GRUB2_EFI_KERNEL_ROOT) ) {
        if ( $self->option(NBPDIR_GRUB2) ) {
            my $kernel_root = dirname($self->option(NBPDIR_GRUB2));
            $kernel_root =~ s/^\/\w+//;
            $kernel_root = '' if ( $kernel_root eq '/' );
            $self->{CONFIG}->set(GRUB2_EFI_KERNEL_ROOT, $kernel_root);
        }
    }
    # GRUB2_EFI_INITRD_CMD is always derived from GRUB2_EFI_LINUX_CMD as
    # Grub2 has a set of linux/initrd command pairs that must match together.
    if ( $self->option(GRUB2_EFI_LINUX_CMD) ) {
        my $initrd_cmd = $self->option(GRUB2_EFI_LINUX_CMD);
        $initrd_cmd =~ s/linux/initrd/;
        if ( $initrd_cmd eq $self->option(GRUB2_EFI_LINUX_CMD) ) {
            $self->error("Commands to load the kernel and initrd are identical ($initrd_cmd)");
        }
        $self->{CONFIG}->define(GRUB2_EFI_INITRD_CMD);
        $self->{CONFIG}->set(GRUB2_EFI_INITRD_CMD, $initrd_cmd);
    }

    return $self;
}


=item _download_options

Extract C<CAF::Download::LWP> or C<CCM> HTTPS (or other)
download related options from aii-shellfe config/options
Returns a hashref with options.
C<type> can be C<lwp> or C<ccm>.

=cut

sub _download_options
{
    my ($self, $type) = @_;

    my @related_opts = (CERT, KEY, CAFILE, CADIR);

    # map AII config option names to the LWP ones
    my $map = {
        lwp => {
            CERT() => 'cert',
            KEY() => 'key',
            CAFILE() => 'cacert',
            CADIR() => 'cadir',
        },
    };

    my $opts = {}; # make sure it can always be used as %$opts
    foreach my $optname (@related_opts) {
        my $val = $self->option($optname);
        if ($val) {
            my $key = $map->{$type}->{$optname} || $optname;
            $opts->{$key} = $val;
        }
    };

    return $opts;
}

=item lock_node

Lock a node being configured, needs to be called in every method that contains
node operations (ie configure etc)

=cut

sub lock_node
{
    my ($self, $node) = @_;
    # /var/lock could be volatile, and the default lockdir depends on it
    mkdir($self->option("lockdir"));
    my $lockfile = $self->option("lockdir") . "/$node";
    my $lock = CAF::Lock->new ($lockfile, log => $self);
    if ($lock && $lock->set_lock(RETRIES, TIMEOUT, FORCE_IF_STALE)) {
        $self->debug(3, "aii-shellfe: locked node $node (lockfile $lockfile)");
        return $lock;
    } else {
        $self->debug(3, "aii-shellfe: failed to lock node $node (lockfile $lockfile)");
        return;
    }
}

=item report

Overwrite the report method to allow the KS plug-in to print
debugging output. See L<CAF::Reporter> for more information.

=cut

sub report
{
    my $self = shift;
    my $msg = join ('', @_);
    print STDOUT "$msg\n" unless $SUPER::_REP_SETUP->{QUIET};
    $self->log (@_);
    return SUCCESS;
}

=item plugin_handler

Handler for exceptions during plugin run

=cut

sub plugin_handler
{
    my ($self, $plugin, $ec, $e) = @_;
    $self->error("$plugin: $e");
    $self->{status} = PARTERR_ST;
    $e->has_been_reported(1);
    return;
}

=item run_plugin

Runs C<method> on the plug-in given at C<path> for node state C<st>
(value of hash returned by fetch_profiles).

C<path> is the PAN path of the plug-in to be run. If the path does not
exist, nothing will be done.

Optional C<modulename> to select the name of the module.
When provided, use module with that name (PAN path is ignored when determining module(s) to use).
When none is provided, all keys of the PAN path will be used as modules.

=cut

# all plugins should return success on success

sub run_plugin
{
    my ($self, $st, $path, $method, $only_modulename) = @_;

    my $name = $st->{name};
    my $tree = $st->{configuration}->getTree($path);
    if (!$tree) {
        $self->verbose("No configuration for plugin path $path for $name. Skipping");
        return;
    }

    # This is here because CacheManager and Fetch objects may have
    # problems when they get out of scope.
    my @modules = $only_modulename ? ($only_modulename) : sort keys %$tree;

    # Iterate over module names, handling each
    foreach my $modulename (@modules) {
        if ($modulename !~ m/^[a-zA-Z_]\w+(::[a-zA-Z_]\w+)*$/) {
            $self->error ("Invalid Perl identifier $modulename specified as a plug-in. Skipping.");
            $self->{status} = PARTERR_ST;
            next;
        }

        local $@;

        my $plug = $self->{plugins}->{$modulename};

        if (!defined $plug) {
            $self->debug (4, "Loading plugin module $modulename");
            eval (USEMODULE . $modulename);
            if ($@) {
                $self->error ("Couldn't load plugin module $modulename for path $path: $@");
                $self->{status} = PARTERR_ST;
                next;
            }

            $self->debug (4, "Instantiating $modulename");
            my $class = MODULEBASE.$modulename;

            # Plugins as derived from NCM::Component, so they need a name argument
            $plug = eval { $class->new($modulename) };
            if ($@) {
                $self->error ("Couldn't call 'new' on plugin module $modulename: $@");
                $self->{status} = PARTERR_ST;
                return;
            }

            $self->{plugins}->{$modulename} = $plug;
        }

        if ($plug->can($method)) {
            $self->debug (4, "Running plugin module $modulename -> $method for $name");
            $aii_shellfev2::__EC__ = LC::Exception::Context->new;
            $aii_shellfev2::__EC__->error_handler(sub {
                $self->plugin_handler($modulename, @_);
            });

            # Set active config
            if ($plug->can('set_active_config')) {
                $plug->set_active_config($st->{configuration});
            }

            # The plugin method has to return success
            my $res = eval { $plug->$method ($st->{configuration}) };
            if ($@) {
                $self->error ("Errors running plugin module $modulename $method method for $name: $@");
                $self->{status} = PARTERR_ST;
            } elsif (! $res) {
                $self->error ("Failed to execute plugin module $modulename $method method for $name");
                $self->{status} = PARTERR_ST;
            }
        } else {
            # TODO: should be warn or error? it's configured, but the code doesn't allow it do anything
            $self->info("no method $method available for plugin module $modulename for $name");
        }
    }

    return;
}

=item dhcp

Runs aii-dhcp on the configuration object received as argument. It
uses the MAC of the first card marked with C<<"boot"=true>>.

=cut

sub dhcp
{
    my ($self, $st, $cmd, $dhcpmgr) = @_;

    my $name = $st->{name};

    # If the profile has a discovery plugin configured, then don't second-guess
    # it - it may or may not be ISC DHCP
    if ($st->{configuration}->elementExists(DISCOVERY)) {
        $self->verbose("Found discovery configuration for path ".DISCOVERY." for $name. Skipping");
        return;
    };

    my $tree = $st->{configuration}->getTree(DHCPPATH);
    if (! $tree) {
        $self->verbose("No configuration for DHCP path ".DHCPPATH." for $name. Skipping");
        return;
    }

    my $mac;
    my $cards = $st->{configuration}->getTree(HWCARDS);
    foreach my $cfg (sort values (%$cards)) {
        if ($cfg->{boot}) {
            if ($cfg->{hwaddr} =~ m{^((?:[0-9a-f]{2}[-:])+(?:[0-9a-f]{2}))$}i) {
                $mac = $1;
                $self->verbose("Using macaddress from (first) boot nic");
                last;
            };
        }
    }

    my $ec;
    if ($cmd eq CONFIGURE) {
        my $opts = $st->{configuration}->getTree(DHCPOPTION);
        $self->debug (4, "Going to add dhcp entry of $name to configure");
        $ec = $dhcpmgr->new_configure_entry($name, $mac, $opts->{tftpserver} // '', $opts->{addoptions} // ());
    } elsif ($cmd eq REMOVEMETHOD) {
        if ($st->{reinstall}) {
            $self->debug(3, "No dhcp removal with reinstall set for $name");
        } else {
            $self->debug (4, "Going to add dhcp entry of $name to remove");
            $ec = $dhcpmgr->new_remove_entry($name);
        }
    } else {
        $self->error("$name: dhcp should only run for configure and remove methods, not $cmd");
        $ec = 1;
    }
    if ($ec) {
        $self->error("Error running method $cmd on $name");
    }
}

=item iter_plugins

Given node state and optional hook, iterate over all plugins in PLUGIN_NAMES.

=cut

sub iter_plugins
{
    my ($self, $st, $hook) = @_;
    foreach my $pluginname (@PLUGIN_NAMES) {
        my $path = "/system/aii/$pluginname";
        if ($self->option("no$pluginname")) {
            $self->verbose("no$pluginname option set, skipping $pluginname plugin");
        } else {
            $self->run_plugin($st, $path, $hook);
        }
    }
}


=item filenodelist

Returns an array with the list of nodes specified in the filename given
as an argument. Each element of the list can be a regular expression.

The second argument is a boolean whether or not the
fully qualified domain name should be used in the profile name.

=cut

sub filenodelist
{
    my ($self, $filename, $fqdn) = @_;

    my @nl;

    my $fh = CAF::FileReader->new($filename, log => $self);

    while (my $l = <$fh>) {
        next if $l =~ m/^#/;
        chomp ($l);
        $self->debug(3, "Evaluating regexp $l");
        push (@nl, $self->nodelist ($l, $fqdn));
    }
    $self->debug (1, "Node list from $filename: " . join (", ", @nl));
    return @nl;
}

=item nodelist

Returns the list of profiles that match a given regular expression.

The second argument is a boolean whether or not the
fully qualified domain name should be used in the profile name.

The original list of all known profiles is determined once
based on the C<cdburl> option.

=cut

sub nodelist
{
    my ($self, $pattern, $fqdn) = @_;

    my $orig_pattern = $pattern;
    # allow the nodename to be specified as either simple nodename, or
    # as filename (i.e. .xml or .json.gz).
    # However, to make sure our regexes make
    # sense, we normalize to forget about the .xml for now.
    # TODO: we are actually normalizing a regex pattern, which is insane

    my $extension = '\.(?:xml|json)(?:\.gz)?$';
    $pattern =~ s{$extension}{};
    my $prefix = $self->option(PREFIX) || '';

    if (!$profiles_info) {
        # Populate the module variable profiles_info with all known profile names
        if ($self->option (CDBURL) =~ m{^dir://(.*)$} ) {
            my $dir = $1;
            $self->debug (4, "Creating profiles-info from local directory $dir");
            # Fake the XMLin structure
            $profiles_info = {profile => [map {{content => basename($_)}} grep {m/$extension/} glob ("$dir/*")]};
        } else {
            my $url = $self->option (CDBURL) . "/" . PROFILEINFO;

            my $lwp = CAF::Download::LWP->new(log => $self);
            my $opts = $self->_download_options('lwp');
            my $rp = $lwp->_do_ua('get', [$url], %$opts);
            $self->debug (4, "Downloading profiles-info: $url");
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

    if ($pattern =~ m{^([^.]*)(.*)}) {
        $pattern = $1;
        $pattern .= "($2)" if $fqdn;
    };

    my @nl;
    foreach my $profile (@{$profiles_info->{profile}}) {
        if ($profile->{content} =~ m/$prefix($pattern)$extension\b/) {
            my $host = $1;
            $self->debug (4, "Added $host to the list");
            push (@nl, $host);
        }
    }

    $self->error ("No node matches $pattern (original $orig_pattern)") unless (@nl);
    return @nl;
}

=item cachedir

Generate the name of the node cachedir from the node name and the C<cachedir> option.

If the C<use_fqdn> opion is used, and additional subdirectory is used (with domainname as value).

=cut

sub cachedir
{
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

=item fetch_profiles

Returns a hash with the node names given as arguments as keys and
a hashref with the C<name> and C<fetch>, C<cachemanager> and C<configuration> instances
associated to their profiles as values.

(This hashref is sometimes referred to as the node state in this code).

=cut

sub fetch_profiles
{
    my ($self, @nl) = @_;

    my $cdb = $self->option (CDBURL);
    my $prefix = $self->option (PREFIX) || '';
    my $suffix = $self->option (SUFFIX) || '';

    if ($suffix =~ m{^([-\w\.]*)$}) {
        $suffix = $1;
    } else {
        $self->error ("Invalid suffix $suffix for profiles");
        $self->{status} = PARTERR_ST;
        return;
    }

    if ($cdb =~ m{([\w\-\.+]+://[+\w\.\-%?=/:]+)}) {
        $cdb = $1;
        # All profiles from dir:// can be accessed as file://
        $cdb =~ s{^dir://}{file://};
    } else {
        $self->error ("Invalid base URL $cdb");
        $self->{status} = PARTERR_ST;
        return;
    }

    # Read the config of the current host
    # Certain parameters (e.g. json_typed) can have an influence on the behaviour
    # and functioning of AII (e.g. json_typed support for rendering).
    EDG::WP4::CCM::CCfg::initCfg();
    my $json_typed = EDG::WP4::CCM::CCfg::getCfgValue('json_typed');
    # Reset to the CCM::CCfg defaults, we will use an isolated config file
    # for each foreign profile
    EDG::WP4::CCM::CCfg::resetCfg();

    my %node_states;
    foreach my $node (@nl) {
        # ignore duplicate entries
        next if exists $node_states{$node};

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
        if (defined($err)) {
            $self->error("failed to create config file $config: ".$err->reason());
            next;
        } else {
            print $cfg_fh "cache_root $ccmdir\n";
            print $cfg_fh "json_typed $json_typed\n";
            print $cfg_fh "tabcompletion 0\n";
            # This is needed to prevent CCM messing with the umask
            print $cfg_fh "world_readable 1\n";

            my $opts = $self->_download_options('ccm');
            foreach my $optname (sort keys %$opts) {
                print $cfg_fh "$optname $opts->{$optname}\n";
            }

            my $changed = $cfg_fh->close() ? "" : "not";
            $self->debug(1, "config file $config $changed changed.");
        };

        # we use CDB_File, since it's the fastest
        my  $fh = EDG::WP4::CCM::Fetch->new ({
            PROFILE_URL => $url,
            FOREIGN => 1,
            CONFIG => $config,
            DBFORMAT => 'CDB_File', # CDB_File is the fastest
            });
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

        my $cm = EDG::WP4::CCM::CacheManager->new($fh->{CACHE_ROOT}, $config);
        if ($cm) {
            my $cfg = $cm->getLockedConfiguration(0);
            $node_states{$node} = {
                name         => $node,
                fetch        => $fh,
                cachemanager => $cm,
                configuration=> $cfg,
            };
        } else {
            $self->error ("Failed to create CacheManager object for node $node. Skipping node.");
            $self->{status} = PARTERR_ST;
        }
        $self->debug (1, "Inserted structure for $node on fetching structure");
    }
    return %node_states;
}

# Initiate the Parallel:ForkManager with requested threads if option is given
sub init_pm
{
    my ($self, $cmd, $responses) = @_;
    if ($self->option('parallel')) {
        my $pm = Parallel::ForkManager->new($self->option('parallel'));
        $pm->run_on_finish ( # called before the first call to start()
            sub {
                my ($pid, $exit_code, $id, $esignal, $cdump, $data_struct_ref) = @_;
                if ($exit_code) {
                    $self->error("Error running $cmd on $id, exitcode $exit_code");
                };
                # retrieve data structure from child
                if (defined($data_struct_ref)) {
                    $responses->{$id} = $data_struct_ref;
                    $self->debug(5, "Running $cmd on $id had output");
                }
            }
        );
        return $pm;
    } else {
        return;
    }
}

# Run the cmd on the list of nodes
sub run_cmd
{
    my ($self, $cmd, %node_states) = @_;
    my $method = "_$cmd";
    my %responses;
    my $pm = $self->init_pm($cmd, \%responses);
    foreach my $node (sort keys %node_states) {
        $self->debug (2, "$cmd: $node");
        if ($cmd ne 'status') {
            my $lock = $self->lock_node($node);
            if (! $lock) {
                $self->error("aii-shellfe: couldn't acquire lock on $node for $cmd");
                next;
            };
        };
        $self->debug(5, "Going to start $cmd on node $node");
        if ($pm) {
            if ($pm->start($node)){
                $self->verbose("started execution for $node in child");
                next;
            } else {
                $self->verbose("child with parallel execution for $node");
            }
        }
        my $ec = $self->$method($node, $node_states{$node}) || 0;
        my $res = { ec => $ec, method => $method, node => $node, mode => $pm ? 1 : 0 };

        if ($pm) {
            $self->verbose("Terminating the child for $node");
            $pm->finish($ec, $res);
        } else {
            $responses{$node} = $res;
        }
    };
    $pm->wait_all_children if $pm;
    $self->debug(2, "Ran $cmd for all requested nodes");
    return \%responses;
}

# Wrapper to execute the commands in sorted manner
no strict 'refs';
foreach my $cmd (COMMANDS) {
    *{$cmd} = sub {
        my ($self, %node_states) = @_;
        return $self->run_cmd($cmd, %node_states);
    }
}
use strict 'refs';


# All the _ methods below should return 0 or undef as success.

=item _install

Runs the Install method of the NBP plugins of the node.

=cut

sub _install
{
    my ($self, $node, $st) = @_;
    $self->run_plugin ($st, NBP, INSTALLMETHOD);
}

=item _status

Runs the Status method of the NBP plugins of the node.

=cut

sub _status
{
    my ($self, $node, $st) = @_;

    $self->debug (1, "Showing the state of $node");
    $self->run_plugin ($st, NBP, STATUSMETHOD);
}

=item _boot

Runs the Boot method of the NBP plugins of the node.

=cut

sub _boot
{
    my ($self, $node, $st) = @_;
    $self->run_plugin ($st, NBP, BOOTMETHOD);
}

=item _firmware

Runs the Firmware method of the NBP plugins of the node.

=cut

sub _firmware
{
    my ($self, $node, $st) = @_;
    $self->run_plugin ($st, NBP, FIRMWAREMETHOD);
}

=item _livecd

Runs the Livecd method of the NBP plugins of the node.

=cut

sub _livecd
{
    my ($self, $node, $st) = @_;
    $self->run_plugin($st, NBP, LIVECDMETHOD);
}

=item _remove

Runs the Unconfigure method of all plugins of the node.

If the node is not being reinstalled, also runs dhcp
and removes the cache dir (unless noaction is set).

=cut

sub _remove
{
    my ($self, $node, $st) = @_;

    $self->iter_plugins($st, REMOVEMETHOD);

    if ($st->{reinstall}) {
        $self->debug(3, "No cache removal with reinstall set for $node");
    } else {
        $self->remove_cache_node($node) unless $self->option('noaction');
    };
}

=item _rescue

Runs the Rescue method of the NBP plugins of the node.

=cut

sub _rescue
{
    my ($self, $node, $st) = @_;

    $self->run_plugin ($st, NBP, RESCUEMETHOD);
}

=item _configure

Runs the Configure method of all plugins and dhcp of the node.

=cut

sub _configure
{
    my ($self, $node, $st) = @_;

    my $when = time();

    my $res = $self->iter_plugins($st, CONFIGURE);
    $self->set_cache_time($node, $when) unless $self->option('noaction');
    return $res;
}

=item _metaconfig

Runs the aii_command method of the metaconfig component of the node.

=cut

sub _metaconfig
{
    my ($self, $node, $st) = @_;
    $self->run_plugin($st, '/software/components/metaconfig', 'aii_command', 'metaconfig');
}

=item get_cache_time

Return the mtime of the C<node> AII statefile.

=cut

sub get_cache_time
{
    my ($self, $node) = @_;

    my $cachedir = $self->cachedir($node);
    return (stat("$cachedir/$STATE_FILENAME"))[9] || 0;
}

=item set_cache_time

Set the mtime of the C<node> AII statefile to C<when>.

=cut

sub set_cache_time {
    my ($self, $node, $when) = @_;

    my $cachedir = $self->cachedir($node);
    my $filename = "$cachedir/$STATE_FILENAME";

    my $fh = CAF::FileWriter->new($filename, mtime => $when, log => $self);
    print $fh '';
    $fh->close();
}

=item remove_cache_node

Remove the C<node> cachedir.
(Does not check the noaction option)

=cut

sub remove_cache_node
{
    my ($self, $node) = @_;
    my $cachedir = $self->cachedir($node);
    rmtree($cachedir);
}

=item check_protected

Given a hash with node states (as returned by C<fetch_profiles>),
remove all protected hosts whose C</system/aii/protected> value does
not match the confirm option.

=cut

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

=item change_dhcp

Make dhcp changes for nodes

=cut

sub change_dhcp
{
    my ($self, $method, %nodes) = @_;

    $self->debug(5, "logfile:", $self->option('logfile'), " dhcpcfg:", $self->option('dhcpcfg'));
    my $dhcpmgr = AII::DHCP->new(
        'script',
        "--logfile=".$self->option('logfile'),
        "--cfgfile=".$self->option('dhcpcfg'),
        log => $self,
        );
    foreach my $node (sort keys %nodes) {
        my $st = $nodes{$node};
        $self->debug(3, "Checking dhcp config on node $node for method $method.");
        if ($st->{configuration}->elementExists(DHCPPATH)) {
            $self->dhcp($st, $method, $dhcpmgr);
        }
    }
    $dhcpmgr->configure_dhcp();

    return 1;
}

=item cmds

Runs all the commands

=cut

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
            if ($self->option(NODHCP)){
                $self->verbose('got option NODHCP, DHCP not enabled');
            } else {
                # If needed, do DHCP here
                if ("$cmd" eq "configure"){
                    $self->change_dhcp(CONFIGURE, %nodes);
                } elsif ("$cmd" eq "remove"){
                    $self->change_dhcp(REMOVEMETHOD, %nodes);
                } else {
                    $self->debug(5, "Method $cmd does not need dhcp");
                }
            }
            $self->verbose (scalar (keys (%nodes)) . " nodes to $cmd");
            $self->$cmd (%nodes);
            $self->info ("ran $cmd on ", scalar (keys (%nodes)), " nodes");
        }
    }

}

=item finish

Run the finish method of all plugins

=cut

sub finish
{
    my ($self) = @_;
    $self->debug(5, "closing down");
    foreach my $pluginname (@PLUGIN_NAMES) {
        my $plugin = $self->{plugins}->{$pluginname};
        if ($plugin && $plugin->can('finish')) {
            $self->debug(5, "invoking finish for $pluginname");
            $plugin->finish();
        }
    }
}

=pod

=back

=cut

1;
