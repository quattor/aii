#${PMpre} NCM::Component::ks${PMpost}

use EDG::WP4::CCM::Path qw (escape unescape);
use NCM::Filesystem 19.12.1;
use NCM::Partition qw (partition_sort);
use NCM::BlockdevFactory 19.12.1 qw (build);

use LC::Exception qw (throw_error);
use CAF::FileWriter;
use CAF::Object;
use Sys::Hostname;
use Text::Glob qw(match_glob);

use parent qw (NCM::Component Exporter);

our $EC = LC::Exception::Context->new->will_store_all;

our $this_app = $main::this_app;
# Modules that may be interesting for hooks.
our @EXPORT_OK = qw (ksuserhooks ksinstall_rpm get_repos replace_repo_glob);

# PAN paths for some of the information needed to generate the
# Kickstart.
use constant { KS               => "/system/aii/osinstall/ks",
               HOSTNAME         => "/system/network/hostname",
               DOMAINNAME       => "/system/network/domainname",
               FS               => "/system/filesystems/",
               PART             => "/system/blockdevices/partitions",
               REPO             => "/software/repositories",
               PRESCRIPT        => "/system/aii/osinstall/ks/pre_install_script",
               PREHOOK          => "/system/aii/hooks/pre_install",
               PREENDHOOK       => "/system/aii/hooks/pre_install_end",
               POSTREBOOTSCRIPT => "/system/aii/osinstall/ks/post_reboot_script",
               POSTREBOOTHOOK   => "/system/aii/hooks/post_reboot",
               POSTREBOOTENDHOOK        => "/system/aii/hooks/post_reboot_end",
               POSTSCRIPT       => "/system/aii/osinstall/ks/post_install_script",
               POSTNOCHROOTHOOK => "/system/aii/hooks/post_install_nochroot",
               POSTHOOK         => "/system/aii/hooks/post_install",
               ANACONDAHOOK     => "/system/aii/hooks/anaconda",
               PREREBOOTHOOK    => "/system/aii/hooks/pre_reboot",
               PKG              => "/software/packages/",
               ACKURL           => "/system/aii/osinstall/ks/ackurl",
               ACKLIST          => "/system/aii/osinstall/ks/acklist",
               SPMA             => "/software/components/spma",
               SPMA_OBSOLETES   => "/software/components/spma/process_obsoletes",
               SPMA_YUMCONF     => "/software/components/spma/main_options",
               ROOTMAIL         => "/system/rootmail",
               AII_PROFILE      => "/system/aii/osinstall/ks/node_profile",
               CCM_PROFILE      => "/software/components/ccm/profile",
               CCM_CONFIG_PATH  => "/software/components/ccm",
               NAMESERVER       => "/system/network/nameserver/0",
               FORWARDPROXY     => "forward",
               LOCALHOST        => hostname(),
               INIT_SPMA_IGN_DEPS   => "/system/aii/osinstall/ks/init_spma_ignore_deps",
           };

# These attributes are not configuration options
# profile is handled separately
use constant CCM_CONFIG_NOOPTIONS => qw(
    active dispatch dependencies configFile version
    profile
);

# Base package path for user hooks.
use constant MODULEBASE       => "AII::";
use constant USEMODULE        => "use " . MODULEBASE;

# use this syslogheader for remote AII scripts logging:
#   190 = local7.info
use constant LOG_ACTION_SYSLOGHEADER => '<190>AII: ';
# awk command to prefix LOG_ACTION_SYSLOGHEADER and
# to insert sleep (usleep by initscripts), throtlles to max 1000 lines per sec
use constant LOG_ACTION_AWK =>
    "awk '{print \"".LOG_ACTION_SYSLOGHEADER."\"\$0; fflush(); system(\"usleep 1000 >& /dev/null\");}'";


# Configuration variable for the osinstall directory.
use constant   KSDIROPT         => 'osinstalldir';

# Lowest supported version is 5.0
use constant ANACONDA_VERSION_EL_5_0 => version->new("11.1");
use constant ANACONDA_VERSION_EL_6_0 => version->new("13.21");
use constant ANACONDA_VERSION_EL_7_0 => version->new("19.31");
use constant ANACONDA_VERSION_EL_8_0 => version->new("29.19");
use constant ANACONDA_VERSION_LOWEST => ANACONDA_VERSION_EL_5_0;


# Return the fqdn of the node
sub get_fqdn
{
    my $cfg = shift;
    my $h = $cfg->getElement (HOSTNAME)->getValue;
    my $d = $cfg->getElement (DOMAINNAME)->getValue;
    return "$h.$d";
}

# return the version instance as specified in the kickstart (if at all)
sub get_anaconda_version
{
    my $kst = shift;
    my $version = ANACONDA_VERSION_LOWEST;
    if ($kst->{version}) {
        $version = version->new($kst->{version});
        if ($version < ANACONDA_VERSION_LOWEST) {
            # TODO is this ok, or should we stop?
            $this_app->error("Version $version < lowest supported ".ANACONDA_VERSION_LOWEST.", continuing with lowest");
            $version = ANACONDA_VERSION_LOWEST;
        }
    };
    return $version;
}


# Opens the kickstart file and sets its handle as the default.
sub ksopen
{
    my ($self, $cfg) = @_;

    my $fqdn = get_fqdn($cfg);

    my $ksdir = $this_app->option (KSDIROPT);
    $self->debug(3,"Kickstart file directory = $ksdir");

    my $ks = CAF::FileWriter->open ("$ksdir/$fqdn.ks",
                                    mode => 0664,
                                    log => $this_app
                                    );
    select ($ks);
}

# Prints the opening here doc statement for the post-reboot
# script. It's usefult to separate this, as other plug-ins might want
# only the post_reboot script.
sub kspostreboot_hereopen
{
    print <<EOF;

cat <<End_Of_Post_Reboot > /etc/rc.d/init.d/ks-post-reboot
EOF
}

# Prints the heredoc closing the KS postreboot statement.
sub kspostreboot_hereclose
{
    print <<EOF;

End_Of_Post_Reboot

EOF
}

# Determine the network device name, and return the
# device ip configuration and any additional network
# options (e.g. to handle with bonding)
# This method is called when setting up
# static network configuration.
sub ksnetwork_get_dev_net
{
    my ($tree, $config) = @_;

    my @networkopts = ();
    my $version = get_anaconda_version($tree);

    my $pxetree = $config->getTree("/system/aii/nbp/pxelinux");
    my $ifaces = $config->getTree("/system/network/interfaces");

    my $dev = $pxetree->{ksdevice};
    my $ipdev = $pxetree->{ipdev};

    if ($dev =~ m!(?:[0-9a-f]{2}(?::[0-9a-f]{2}){5})|bootif|link!i) {
        $this_app->error("Invalid ksdevice $dev for static ks configuration.");
        return;
    }

    if (!$ifaces->{$dev}) {
        $this_app->error("ksdevice $dev missing network details for static ks configuration.");
        return;
    }

    $this_app->verbose("Using IP config from $ipdev instead of $dev.") if $ipdev;
    my $net = $ifaces->{$ipdev || $dev};

    # check for bonding
    my $bonddev = $net->{master};
    # check the existence to deal with older profiles
    if (exists($tree->{bonding}) && (! $tree->{bonding})) {
        my $msg = "Bonding config generation explicitly disabled";
        $this_app->debug (5, $msg);
        # lets hope you know what you are doing
        $this_app->warn ("$msg for dev $dev, with master $bonddev set.") if ($bonddev);
    } elsif ($version >= ANACONDA_VERSION_EL_6_0 && $bonddev ) {
        # this is the dhcp code logic; adding extra error here.
        if (!($net->{bootproto} && $net->{bootproto} eq "none")) {
            $this_app->warn("Pretending this a bonded setup with bonddev $bonddev (and ksdevice $dev).",
                             "But bootproto=none is missing, so ncm-network will not treat it as one.");
        }
        $this_app->debug (5, "Ksdevice $dev is a bonding slave, node will boot from bonding device $bonddev");

        # network settings are part of the bond master
        if ($ipdev && $ipdev ne $bonddev) {
            $this_app->verbose("Using ipdev $ipdev configured instead of bond device $bonddev")
        } else {
            $net = $ifaces->{$bonddev};
        }

        # gather the slaves, the ksdevice is put first
        my @slaves;
        push(@slaves, $dev);
        foreach my $intf (sort keys %$ifaces) {
            push (@slaves, $intf) if ($ifaces->{$intf}->{master} &&
                                      $ifaces->{$intf}->{master} eq $bonddev &&
                                      !(grep { $_ eq $intf } @slaves));
        };

        push(@networkopts, "--bondslaves=".join(',', @slaves));

        # gather the options
        my $bond_opts = $net->{bonding_opts};
        if ($bond_opts) {
            my @opts;
            foreach my $key (sort keys %$bond_opts) {
                push(@opts, "$key=".$bond_opts->{$key});
            }
            push(@networkopts, "--bondopts=".join(',', @opts));
        }

        # continue with the bond device as network device
        $dev = $bonddev;

    }

    return ($dev, $ipdev, $ifaces->{$dev}, $net, @networkopts);
}


# Configures the network, allowing both DHCP and static boots.
sub ksnetwork
{
    my ($tree, $config) = @_;

    my $version = get_anaconda_version($tree);
    my @network = qw(network);

    if ($tree->{bootproto} eq 'dhcp') {
        # TODO: no boot device selection with dhcp (e.g. needed for bonding)
        # Although fully supported in ks and easy to add,
        # the issue here is backwards compatibilty (a.k.a. very old behaviour)
        $this_app->debug (5, "Node configures its network via DHCP");
        push(@network, "--bootproto=dhcp");
        if ($version >= ANACONDA_VERSION_EL_7_0) {
            # For some reason, NetworkManager does not want to use the hostname
            # returned by DHCP on RH7
            my $fqdn = get_fqdn($config);
            push(@network, "--hostname=$fqdn");
        }
        return @network;
    }

    push(@network, "--bootproto=static");

    my ($dev, $ipdev, $devnet, $net, @networkopts) = ksnetwork_get_dev_net($tree, $config);
    push(@network, @networkopts);

    $this_app->debug (5, "Node will boot from $dev");
    push(@network, "--device=$dev");

    my $fqdn = get_fqdn($config);
    push(@network, "--hostname=$fqdn");

    my $ns = $config->getElement(NAMESERVER)->getValue;
    push(@network, "--nameserver=$ns");

    # from now on, only IP related settings

    # check for bridge: if $dev is a bridge interface,
    # continue with network settings on the bridge device
    # (do this here, i.e. after --device is set)
    my $brdev = $devnet->{bridge} || $devnet->{ovs_bridge};
    if ($brdev) {
        $this_app->debug (5, "Device $dev is a bridge interface for bridge $brdev.");
        # continue with network settings for the bridge device
        if ($ipdev && $ipdev ne $brdev) {
            $this_app->verbose("Using ipdev $ipdev configured instead of bridge device $brdev")
        } else {
            $net = $config->getElement("/system/network/interfaces/$brdev")->getTree;
        }
        # warning: $dev is changed here to the bridge device to create correct log
        # messages in remainder of this method. as there is not bridge device
        # in anaconda phase, the new value of $dev is not an actual network device!
        $dev = $brdev;
    }

    unless ($net->{ip}) {
        $this_app->error ("Static boot protocol specified ",
                          "but no IP given to the interface $dev");
        return ();
    }
    push(@network, "--ip=$net->{ip}", "--netmask=$net->{netmask}");

    push(@network, "--mtu=$net->{mtu}") if $net->{mtu};

    my $gw = '--gateway=';
    if ($net->{gateway}) {
        $gw .= $net->{gateway};
    } elsif ($config->elementExists ("/system/network/default_gateway")) {
        $gw .= $config->getElement ("/system/network/default_gateway")->getValue;
    } else {
        # This is a recipe for disaster
        # Best guess is that no gateway is needed.
        $this_app->debug (5, "No gateway defined for dev $dev and ",
                          " using static network description.",
                          "Let's hope everything is reachable through a ",
                          "direct route.");
        $gw='';
        print <<EOF;
## No gateway defined for dev $dev and using static network description.
## Lets hope all is reachable through direct route.
EOF
    };
    push(@network, $gw);

    return @network;
}

# Instantiates and executes the user hooks for a given path.
# The module is first tried with prefixed AII:: namespace,
# then on its own and then in NCM::Component namespace with
# method name prefixed with aii_
sub ksuserhooks
{
    my ($config, $path) = @_;

    my $hooks = $config->getTree($path);
    return unless defined($hooks);

    $this_app->debug (5, "User defined hooks for $path");

    my $method_name;
    if ($path =~ m(/system/aii/hooks/([^/]+))) {
        $method_name = $1;
    } else {
        $this_app->error("No method for user defined hooks for $path");
        return;
    };

    my $idx = -1;
    foreach my $hook (@$hooks) {
        $idx++;
        # Can be prefixed with aii_
        my $method = $method_name;

        my $shortname;
        if ($hook->{module} =~ m/^(?:[_a-zA-Z]\w+::)*([_a-zA-Z]\w+)$/) {
            $shortname = $1;
        } else {
            $this_app->error ("Invalid identifier $hook->{module} specified as a hook module. Skipping");
            next;
        }

        my $modulename = MODULEBASE . $hook->{module};
        $this_app->debug (5, "Loading hook module $modulename");

        eval ("use $modulename");
        if ($@) {
            # Fallback: try without the AII:: prefix
            my $orig_error = $@;

            $this_app->debug (5, "Loading fallback hook module $hook->{module}");
            eval ("use $hook->{module}");
            if ($@) {
                # Report the original error message if the fallback failed
                throw_error ("Couldn't load hook module $hook->{module} ($modulename): $orig_error");
            } else {
                $modulename = $hook->{module};
            }
        }

        my @args;
        if ($modulename =~ m/^NCM::Component::/) {
            # pass name and logger
            push(@args, $shortname, $this_app);
            # change the method name for components
            $method = "aii_$method";
        };

        my $hook_inst = eval { $modulename->new(@args) };
        if ($@) {
            throw_error ("Couldn't instantiate object of hook class $hook->{module} ($modulename): $@");
        } else {
            if ($hook_inst->can($method)) {
                if ($hook_inst->can('set_active_config')) {
                    $hook_inst->set_active_config($config);
                }

                $this_app->debug (5, "Running hook $hook->{module} method $method ($modulename->$method)");
                $hook_inst->$method ($config, "$path/$idx");
            } else {
                throw_error ("Hook instance class $hook->{module} ($modulename) has no $method method");
            }
        }
    }
}

# Prints to the Kickstart all the non-partitioning directives.
# Returns the reference to the list of unprocessed packages.
sub kscommands
{
    my  $config = shift;

    my $tree = $config->getElement(KS)->getTree;
    my $version = get_anaconda_version($tree);

    my @packages = @{$tree->{packages}};
    push(@packages, 'bind-utils'); # required for nslookup usage in ks-post-install

    my $repos = get_repos($config);
    # error reported in get_repos
    return if ! $repos;

    my $proxy = proxy($config);

    my $installtype = $tree->{installtype};
    my $proxy_noglob = sub {
        my $txt = shift;
        return [proxy_url($proxy, $txt)]
    };
    my $inst_msg = "installtype $installtype";
    my $inst_globbed = replace_repo_glob($installtype, $repos, $proxy_noglob, 'url', {proxy => 'proxy'}, $inst_msg);
    if (defined($inst_globbed)) {
        $installtype = $inst_globbed->[0];
    } else {
        $this_app->error("$inst_msg glob had no matches");
        return;
    }

    my $ntp_servers = '';
    if ($tree->{ntpservers} && $version >= ANACONDA_VERSION_EL_7_0) {
        $ntp_servers = ' --ntpservers=' . join(',', @{$tree->{ntpservers}});
    }

    if ($version < ANACONDA_VERSION_EL_8_0) {
        print "install\n";
    }

    print <<EOF;
$installtype
reboot
timezone --utc $tree->{timezone}$ntp_servers
rootpw --iscrypted $tree->{rootpw}
EOF

    my %repo_opt_map = map {$_ => $_} (qw(name proxy includepkgs excludepkgs));

    foreach my $url (@{$tree->{repo} || []}) {
        my $globbed = replace_repo_glob($url, $repos, $proxy_noglob, 'baseurl', \%repo_opt_map);
        if (defined($globbed)) {
            foreach my $newurl (@$globbed) {
                print "repo $newurl\n";
            }
        } else {
            $this_app->error("repo url $url glob had no matches");
            return;
        }
    }

    if ($tree->{cmdline}) {
        print "cmdline\n";
    } else {
        print "text\n";
    }

    if ($tree->{enable_sshd} && $version >= ANACONDA_VERSION_EL_6_0) {
        print "sshpw --username=root $tree->{rootpw} --iscrypted\n";
    }
    if ($tree->{eula} && $version >= ANACONDA_VERSION_EL_7_0) {
        print "eula --agreed\n";
    }

    if ($tree->{logging} && $tree->{logging}->{host}) {
        print "logging --host=$tree->{logging}->{host} ",
            "--port=$tree->{logging}->{port}";
        print " --level=$tree->{logging}->{level}" if $tree->{logging}->{level};
        print "\n";
        if($tree->{logging}->{send_aiilogs}) {
            # requirement for usleep
            push(@packages, 'initscripts');
            push(@packages, 'nc') if ($tree->{logging}->{method} eq 'netcat');
        }
    }
    print "bootloader --location=$tree->{bootloader_location}";
    print " --driveorder=", join(',', @{$tree->{bootdisk_order}})
        if $tree->{bootdisk_order} && @{$tree->{bootdisk_order}};
    print " --append=\"$tree->{bootloader_append}\""
        if $tree->{bootloader_append};
    print " --password=\"$tree->{bootloader_password}\" --iscrypted"
        if $tree->{bootloader_password};
    if ($tree->{leavebootorder} && $version >= ANACONDA_VERSION_EL_7_0) {
        print " --leavebootorder";
    }
    print "\n";

    if ($tree->{xwindows}) {
        print "xconfig ";
        while (my ($key, $val) = each %{$tree->{xwindows}}) {
            if ($key eq "startxonboot") {
                print "--$key " if $val;
            } else {
                print "--$key=$val ";
            }
        }
        print "\n";
    } else {
        print "skipx\n";
    }

    print "key $tree->{installnumber}\n" if exists $tree->{installnumber};
    print "auth ", join(" ", map("--$_",  @{$tree->{auth}})), "\n";
    print "lang $tree->{lang}\n";
    print "langsupport ", join (" ", @{$tree->{langsupport}}), "\n"
        if $tree->{langsupport} and @{$tree->{langsupport}}[0] ne "none";

    print "keyboard ", $version >= ANACONDA_VERSION_EL_7_0 ? "--xlayouts=" : "", "$tree->{keyboard}\n";
    print "mouse $tree->{mouse}\n" if exists $tree->{mouse};

    print "selinux --$tree->{selinux}\n" if exists $tree->{selinux};

    print "firewall --", $tree->{firewall}->{enabled}? "en":"dis", "abled ";
    print "--trusted $_ " foreach @{$tree->{firewall}->{trusted}};
    print "--$_ " foreach @{$tree->{firewall}->{services}};
    print "--port $_ " foreach @{$tree->{firewall}->{ports}};
    print "\n";

    print join(" ",ksnetwork ($tree, $config)), "\n";

    print "driverdisk --source=$_\n" foreach @{$tree->{driverdisk}};
    print "zerombr\n" if ($tree->{clearmbr});
    if ($tree->{ignoredisk} &&
        scalar (@{$tree->{ignoredisk}})) {
        print "ignoredisk --drives=",
            join (',', @{$tree->{ignoredisk}}), "\n";
    }

    ## disable and enable services, if any
    my @services;
    push(@services, "--disabled=".join(',', @{$tree->{disable_service}})) if
        ($tree->{disable_service} && @{$tree->{disable_service}});
    push(@services, "--enabled=".join(',', @{$tree->{enable_service}})) if
        ($tree->{enable_service} && @{$tree->{enable_service}});

    print "services ", join (' ', @services), "\n" if (@services);

    # packages are dealt last. This returns the reference to the list of unprocessed packages
    # by default, all packages are processed
    my $unprocessed_packages = [];

    print "%packages";
    my @packages_in_packages = @packages;
    if ($tree->{packagesinpost}) {
        # to be installed later in %post using all repos
        # disabled/ignored packages can be handled in packagesinpost (at least in EL7+),
        # but better make sure they are not pulled in via some other method, so adding them here as well
        my $pattern = '^-';
        @packages_in_packages = grep {m/$pattern/} @packages;

        # for EL7+, use never matching pattern, so all packages are also carried over
        # to the %post section (incl the ones starting with a -)
        $pattern = '$^' if $version >= ANACONDA_VERSION_EL_7_0;

        push(@$unprocessed_packages, grep {$_ !~ m/$pattern/} @packages);
    }

    if (@packages_in_packages) {
        print " ", join(" ",@{$tree->{packages_args}}), "\n",
            join ("\n", @packages_in_packages);
    }
    print "\n";
    print $version >= ANACONDA_VERSION_EL_6_0 ? '%end' : '', "\n";

    return $unprocessed_packages, $repos;
}

# Writes the mountpoint definitions and LVM and MD settings
sub ksmountpoints
{
    my $config = shift;

    # Skip the remainder if "/system/filesystems" is undefined
    return unless ( $config->elementExists (FS) );

    my $tree = $config->getElement(KS)->getTree;
    my $version = get_anaconda_version($tree);

    my %ignoredisk;
    if ($tree->{ignoredisk} &&
        scalar (@{$tree->{ignoredisk}})) {
        foreach my $disk (@{$tree->{ignoredisk}}) {
            $ignoredisk{$disk} = 1;
        }
    }

    print <<EOF;

# Mountpoint and block device definition.  At this stage, LVM and MD
# settings are defined for Anaconda to be able to use them.  All block
# devices (LVM and MD included) are actually created on the %pre
# phase.

EOF

    my $fss = $config->getElement (FS);
    while ($fss->hasNextElement) {
        my $fs = $fss->getNextElement;

        my $aii = $fs->getTree()->{aii};
        next if defined($aii) && !$aii;

        my $fstree = NCM::Filesystem->new ($fs->getPath->toString,
                                           $config, anaconda_version => $version);
        next if ($fstree->{block_device}->{holding_dev} &&
                 $ignoredisk{$fstree->{block_device}->{holding_dev}->{devname}});
        $this_app->debug (5, "Pre-processing filesystem $fstree->{mountpoint}");

        $fstree->print_ks;
    }
}

# Prints the code for downloading and executing an user script.
sub ksuserscript
{
    my ($config, $path) = @_;

    return unless $config->elementExists ($path);
    my $url = $config->getElement ($path)->getValue;
    $url =~ s{LOCALHOST}{LOCALHOST}e;
    $this_app->debug (5, "User defined script to be fetched ",
                      "from $url for path $path");

    print <<EOS;
pushd /root
wget --timeout 60 --output-document=userscript $url || fail "Failed to download $url"
chmod +x userscript
./userscript
rm -f userscript
popd
EOS
}

# Takes care of the install phase, where all the fixed directives are
# placed. Retuns reference to list of unprocessed packages.
sub install
{
    my ($self, $config) = @_;

    print <<EOF;
# Kickstart generated by AII's ks.pm.
# Do not edit.
#
# AII is part of Quattor, see more information on Quattor and its license
# at http://www.quattor.org

EOF
    ksmountpoints ($config);

    # User hooks must be included before the commands because the latter
    # ends with the %postconfig section
    ksuserhooks ($config, ANACONDAHOOK);

    my ($packages, $repos) = kscommands ($config);

    return $packages, $repos;
}

# Create the action to be taken on the log files
# logfile is the path to the log file
sub log_action {
    my ($config, $logfile, $wait_for_network) = @_;

    my $tree = $config->getElement(KS)->getTree;
    my @logactions;
    my $drainsleep = 0;

    push(@logactions, "exec >$logfile 2>&1");

    # when changing any of the behaviour
    my $consolelogging = 1; # default behaviour
    if ($tree->{logging}) {
        # although mandatory in the schema (for now?), if it is missing, it should be 1
        # adding the if(defined()) here for that reason
        $consolelogging = $tree->{logging}->{console} if (defined($tree->{logging}->{console}));

        if ($tree->{logging}->{send_aiilogs}) {
            # network must be functional
            # (not needed in %pre and %post; we can rely on anaconda for that)
            push(@logactions, "wait_for_network $tree->{logging}->{host}")
                if ($wait_for_network);

            my $method = $tree->{logging}->{method};
            my $protocol = $tree->{logging}->{protocol};

            my $actioncmd;
            if ($method eq 'netcat') {
                push(@logactions,'# Send messages to $protocol syslog server via netcat');
                # use netcat to log to syslog port
                my $nccmd = 'nc';
                $nccmd .= ' -u' if ($protocol eq 'udp');

                $actioncmd = "| $nccmd $tree->{logging}->{host} $tree->{logging}->{port}";
            } elsif ($method eq 'bash') {
                push(@logactions,"# Send messages to $protocol syslog server via bash /dev/$protocol");
                # use netcat to log to UDP syslog port
                # this assumes that the %pre, %post and post-reboot are bash
                $actioncmd = "> /dev/$protocol/$tree->{logging}->{host}/$tree->{logging}->{port}";
            }

            my $action = "(tail -f $logfile | ".LOG_ACTION_AWK." $actioncmd) &";
            push(@logactions, $action);

            # insert extra sleep to get all started before any output is send
            push(@logactions, 'sleep 1');

            # fix drain sleep to 10 seconds
            $drainsleep = 10;
        }
    }

    if ($consolelogging) {
        # In EL7, /dev/console doesn't add the carriage return for each line feed (new line)
        # resulting in unreadable messages on the console. /dev/pts/0 must be used instead.
        # But on prior versions, /dev/pts/0 doesn't exist at installation time and cannot be used.
        # The following code allows to use /dev/pts/0 if it exists else to revert to /dev/console.
        push(@logactions, "console='/dev/console'");
        push(@logactions, "[ -c /dev/pts/0 ] && console='/dev/pts/0'");
        push(@logactions, '# Make sure messages show up on the serial console',
                          "tail -f $logfile > \$console &");
    }

    push(@logactions,"drainsleep=$drainsleep"); # add trailing newline
    push(@logactions,''); # add trailing newline
    return join("\n", @logactions)
}

# Takes care of the pre-install script, in which the
sub pre_install_script
{
    my ($self, $config) = @_;

    my $logfile = '/tmp/pre-log.log';
    my $logaction = log_action($config, $logfile);

    my $kstree = $config->getElement(KS)->getTree;
    my $version = get_anaconda_version($kstree);

    print <<EOF;
%pre

# Pre-installation script.
#
# Block devices are created here instead of using Anaconda's
# directives to allow better control. Anaconda doesn't guarantee that
# the devices it creates will have the exact name it is told to. For
# instance, if you define 4 primary partitions, it will create 3
# primary, one extended and your /dev/foo4 will be silently renamed to
# /dev/foo5.

$logaction
echo 'Begin of pre section'
set -x

EOF

    if ($version < ANACONDA_VERSION_EL_6_0) {
        print <<'EOF';
wipe_metadata () {
    local path clear SIZE ENDSEEK ENDSEEK_OFFSET
    path="$1"

    # default to 1
    clearmb="${2:-1}"

    # wipe at least 4 MiB at begin and end
    ENDSEEK_OFFSET=4
    if [ "$clearmb" -gt $ENDSEEK_OFFSET ]; then
        ENDSEEK_OFFSET=$clearmb
    fi

    # try to get the size with fdisk
    SIZE=`disksize_MiB "$path"`

    # if empty, assume we failed and try with parted
    if [ $SIZE -eq 0 ]; then
        # the SIZE has not been determined,
        # set it equal to ENDSEEK_OFFSET, the entire disk gets wiped.
        SIZE=$ENDSEEK_OFFSET
        echo "[WARN] Could not determine the size of device $path with both fdisk and parted. Wiping whole drive instead"
    fi

    let ENDSEEK=$SIZE-$ENDSEEK_OFFSET
    if [ $ENDSEEK -lt 0 ]; then
        ENDSEEK=0
    fi
    echo "[INFO] wipe path $path with SIZE $SIZE and ENDSEEK $ENDSEEK"
    # dd with 1 MiB blocksize (unit used by disksize_MiB and faster then e.g. bs=512)
    dd if=/dev/zero of="$path" bs=1048576 count=$ENDSEEK_OFFSET
    dd if=/dev/zero of="$path" bs=1048576 seek=$ENDSEEK
    sync
}
EOF
    } else {
        my $force = $version >= ANACONDA_VERSION_EL_7_0 ? " --force" : "";
        print <<"EOF";
wipe_metadata () {
    local path
    path="\$1"

    wipefs --all$force "\$path"
    dmsetup remove --retry "\$path" 2>/dev/null
}
EOF
    }

    print <<'EOF';

disksize_MiB () {
    local path BYTES MB RET
    RET=0
    path="$1"
    BYTES=`blockdev --getsize64 "$path" 2>/dev/null`
    if [ -z $BYTES ]; then
        BYTES=`fdisk -l "$path" 2>/dev/null |sed -n "s#^Disk\s$path.*\s\([0-9]\+\)\s*bytes.*#\1#p"`
        if [ -z $BYTES ]; then
            BYTES=0
            RET=1
        fi
    fi
    # use MiB
    let MB=$BYTES/1048576
    echo $MB
    return $RET
}

valid_disksize_MiB () {
    # takes 3 args: device path, minimum size and maximum size
    # uses exitcode for result (e.g. if [ $? -ne 0 ] to test for failure)
    local path min max SIZE RET
    msg="ERROR"
    RET=1
    path="$1"
    min="$2"
    if [ -z $min ]; then
        min=0
    fi
    max="$3"
    if [ -z $max ]; then
        max=$min
    fi
    SIZE=`disksize_MiB "$path"`
    if [ $SIZE -ge $min -a $SIZE -le $max ]; then
        msg="INFO"
        RET=0
    fi
    echo "[$msg] Found path $path size $SIZE min $min max $max"
    return $RET
}

EOF

    # Hook handling should come here, to allow NIKHEF to override
    # partitioning.
    ksuserhooks ($config, PREHOOK);

    $self->ksprint_filesystems ($config);
    # Is this needed if we are allowing for hooks?
    ksuserscript ($config, PRESCRIPT);

    ksuserhooks ($config, PREENDHOOK);

    print <<EOF;

# De-activate logical volumes. Needed on RHEL6, see:
# https://bugzilla.redhat.com/show_bug.cgi?id=652417
lvm vgchange -an
EOF

    # mdadm devices should be stopped at the end of the pre-ks phase on EL7
    if ($version >= ANACONDA_VERSION_EL_7_0) {
        print "mdadm --stop --scan\n";
    }

    print <<EOF;
echo 'End of pre section'

# Drain remote logger (0 if not relevant)
sleep \$drainsleep

%end

EOF

}

# Prints the code needed for removing and creating partitions, block
# devices and filesystems
sub ksprint_filesystems
{
    my ($self, $config) = @_;

    # Skip the remainder if "/system/filesystems" is not defined
    return unless ( $config->elementExists (FS) );

    my $kstree = $config->getElement(KS)->getTree;
    my $version = get_anaconda_version($kstree);

    my $fss = $config->getElement (FS);
    my @filesystems = ();

    # Destroy what needs to be destroyed.
    my $clear = [];

    if ($config->elementExists ("/system/aii/osinstall/ks/clearpart")) {
        $clear = $config->getElement ("/system/aii/osinstall/ks/clearpart")->getTree;
    }

    # cleanup/wipe partitions etc
    while ($fss->hasNextElement) {
        my $fs = $fss->getNextElement;

        my $aii = $fs->getTree()->{aii};
        next if defined($aii) && !$aii;

        my $fstree = NCM::Filesystem->new ($fs->getPath->toString,
                                           $config, anaconda_version => $version);
        $fstree->del_pre_ks;
        push (@filesystems, $fstree);
    }

    # only after cleaning up the partitions etc, perform the clearpart
    # (clearpart_ks wipes disk and sets boot label, any parttion cleanup
    # is useless after that)
    foreach (@$clear) {
        my $disk = build ($config, "physical_devs/".escape($_), anaconda_version => $version);
        $disk->clearpart_ks;
    }

    # Create what needs to be created.
    my $pts = $config->getElement (PART);
    my @part = ();
    while ($pts->hasNextElement) {
        my $p = $pts->getNextElement;

        my $aii = $p->getTree()->{aii};
        next if defined($aii) && !$aii;

        my $pt = NCM::Partition->new ($p->getPath->toString,
                                      $config, anaconda_version => $version);

        # EL7+ parted doesn't seem to understand/like logical partitions
        # without clear offset
        if ($version >= ANACONDA_VERSION_EL_7_0 &&
                ! exists $pt->{offset} &&
                $pt->{holding_dev}->{label} &&
                $pt->{holding_dev}->{label} eq 'msdos' &&
                $pt->{type} &&
                $pt->{type} eq 'logical') {
             $pt->{offset}=1;
        }

        push (@part, $pt);
    }
    # Partitions go first, as of bug #26137
    $_->create_pre_ks foreach (partition_sort(@part));

    $_->create_ks foreach @filesystems;

    # Ensure that all LVMs are active before formatting anything, or
    # they won't appear during the reinstallation process.
    if ($config->elementExists("/system/blockdevices/logical_volumes")) {
        print <<EOF;
lvm vgscan --mknodes
lvm vgchange -ay
EOF
    }

    $_->format_ks foreach @filesystems;

}

# Prints the statements needed to install a given set of RPMs
sub ksinstall_rpm
{
    my ($config, @pkgs) = @_;

    return unless @pkgs;

    my $tree = $config->getElement(KS)->getTree;
    my $version = get_anaconda_version($tree);

    my $packager = $version >= ANACONDA_VERSION_EL_8_0 ? "dnf" : "yum";
    print join("\\\n    ",
               "$packager -c /var/tmp/aii/yum/yum.conf -y install",
               (map {s/^-//; "-x '$_'"} grep {$_ =~ /^-/} @pkgs),
               (grep {$_ !~ /^-/} @pkgs)
        ), " || fail 'Unable to install packages'\n";
}

sub proxy
{
    my ($config) = @_;

    my $proxy = {};

    my $spma = $config->getTree(SPMA);
    my $use_proxy = $spma->{proxy} || 0;
    # old SPMA boolean_yes_no schema
    $use_proxy = $use_proxy eq "yes" ? 1 : 0;

    if ($use_proxy) {
        my $tmp_proxyhost = $spma->{proxyhost};
        my @proxies = split /,/, $tmp_proxyhost;
        if (scalar(@proxies) == 1) {
            # there's only one proxy specified
            $proxy->{host} = $spma->{proxyhost};
        } elsif (scalar(@proxies) > 1) {
            # optimize by picking the responding server as the proxy
            my $localhost = LOCALHOST;  # need a variable, not a constant
            my ($me) = grep { /\b$localhost\b/ } @proxies;
            $me ||= $proxies[0];
            $proxy->{host} = $me;
        }

        if ($spma->{proxyport}) {
            $proxy->{port} = $spma->{proxyport};
        }
        if ($spma->{proxytype}) {
            $proxy->{type} = $spma->{proxytype};
        }
    }

    return $proxy;
}

# adapt url with reverse proxy settings
# returns possibly modified url
sub proxy_url
{
    my ($proxy, $url) = @_;

    if ($url =~ /http/) {
        if ($proxy->{host} && ($proxy->{type} || '') eq "reverse") {
            my $proxyhost = $proxy->{host};
            if ($proxy->{port}) {
                $proxyhost .= ":$proxy->{port}";
            }
            $url =~ s{(https?)://([^/]*)/}{$1://$proxyhost/};
        }
    }

    return $url;
}

# Prints the header functions and definitions of the post_reboot
# script.
sub kspostreboot_header
{
    my $config = shift;

	# TODO is it ok to rename this logfile?
    my $logfile = '/root/ks-post-reboot.log';
    my $logaction = log_action($config, $logfile, 1);
    $logaction =~ s/\$/\\\$/g;

    my $fqdn = get_fqdn($config);

    my $rootmail = $config->getElement (ROOTMAIL)->getValue;
    my $tree = $config->getTree(KS);

    # Legacy setting precedes
    my $mailonsuccess = defined($tree->{email_success}) ? $tree->{email_success} : $tree->{mail}->{success};
    my $return_no_success_mail = $mailonsuccess ? '' : "# No mail on success\n    return";

    my $mailx_smtp = "";
    $mailx_smtp .= " smtp=$tree->{mail}->{smtp}" if $tree->{mail}->{smtp};
    # support for s-nail on el9
    my $snail_smtp = "";
    $snail_smtp .= "  -Smta=smtp://$tree->{mail}->{smtp}" if $tree->{mail}->{smtp};

    print <<EOF;
#!/bin/bash
# Script to run at the first reboot. It installs the base Quattor RPMs
# and runs the components needed to get the system correctly
# configured.

# Minimal init script compatibility
if [ "\\\$1" != start ]; then
    exit 0
fi

hostname $fqdn

# Function to be called if there is an error in this phase.
# It sends an e-mail to $rootmail alerting about the failure.
fail() {
    echo "Quattor installation on $fqdn failed: \\\$1"
    subject="[\\`date +'%x %R %z'\\`] Quattor installation on $fqdn failed: \\\$1"
    if [ -x /usr/bin/mailx ]; then
        mailx_options="from=root\@$fqdn $mailx_smtp mailx"
        if [ -x /usr/bin/s-nail ]; then
            mailx_options="mailx -:/ -Sfrom=root\@$fqdn $snail_smtp"
        fi
        env MAILRC=/dev/null \\\$mailx_options -s "\\\$subject" $rootmail <<End_of_mailx

\\`cat $logfile\\`
------------------------------------------------------------
\\`ls -tr /var/log/ncm 2>/dev/null|xargs tail /var/log/spma.log\\`

End_of_mailx
    else
        sendmail -t <<End_of_sendmail
From: root\@$fqdn
To: $rootmail
Subject: \\\$subject

\\`cat $logfile\\`
------------------------------------------------------------
\\`ls -tr /var/log/ncm 2>/dev/null|xargs tail /var/log/spma.log\\`

.
End_of_sendmail
    fi
    # Drain remote logger (0 if not relevant)
    sleep \\\$drainsleep
    exit 1
}

# Function to be called if the installation succeeds.  It can send an
# e-mail to $rootmail alerting about the installation success.
success() {
    echo "Quattor installation on $fqdn succeeded"
    $return_no_success_mail

    subject="[\\`date +'%x %R %z'\\`] Quattor installation on $fqdn succeeded"
    if [ -x /usr/bin/mailx ]; then
        mailx_options="from=root\@$fqdn $mailx_smtp mailx"
        if [ -x /usr/bin/s-nail ]; then
            mailx_options="mailx -:/ -Sfrom=root\@$fqdn $snail_smtp"
        fi
        env MAILRC=/dev/null \\\$mailx_options -s "\\\$subject" $rootmail <<End_of_mailx

Node $fqdn successfully installed.

End_of_mailx
    else
        sendmail -t <<End_of_sendmail
From: root\@$fqdn
To: $rootmail
Subject: \\\$subject

Node $fqdn successfully installed.
.
End_of_sendmail
    fi
    # Drain remote logger (0 if not relevant)
    sleep \\\$drainsleep
}

# Wait for functional network up by testing DNS lookup via nslookup.
wait_for_network () {
    # Wait up to 2 minutes until the network comes up
    i=0
    while ! nslookup \\\$1 > /dev/null
    do
        sleep 1
        let i=\\\$i+1
        if [ \\\$i -gt 120 ]
        then
            fail "Network does not come up (nslookup \\\$1)"
        fi
    done
}

# Ensure that the log file doesn't exist.
[ -e $logfile ] && \\
    fail "Last installation went wrong. Aborting. See logfile $logfile."

$logaction
echo 'Begin of ks-post-reboot'
set -x

wait_for_network $fqdn

EOF

}

sub ksquattor_config
{
    my $config = shift;

    print <<EOF;

# SPMA transactions may open HUGE amounts of files at the same time.
ulimit -n 8192

cat <<End_Of_CCM_Conf > /etc/ccm.conf
# Base configuration for CCM
# Generated by AII Kickstart Generator
EOF

    my $prof_path = $config->elementExists (AII_PROFILE) ? AII_PROFILE : CCM_PROFILE;
    print "profile ", $config->getElement ($prof_path)->getValue, "\n";

    my $ccm_conf = $config->getTree(CCM_CONFIG_PATH);
    foreach my $noconf (CCM_CONFIG_NOOPTIONS()) {
        delete $ccm_conf->{$noconf};
    }

    foreach my $key (sort keys %$ccm_conf) {
        # This is the ncm-ccm code of 16.2
        my $v = $ccm_conf->{$key};
        my $value = ref($v) eq 'ARRAY' ? join(',', @$v) : $v;
        print "$key $value\n" if length($value);
    }

    print "End_Of_CCM_Conf\n";

    print <<EOF;

/usr/sbin/ccm-initialise || fail "CCM initialization failed with code \\\$?"
/usr/sbin/ccm-fetch || fail "ccm-fetch failed with code \\\$?"
# we want nscd running in case the NSS config
# gets modified (ncm-ncd will be bound to nscd for
# lookups and therefore an nscd bounce will cause
# ncm-ncd to immediately notice the changes, which
# means that components that rely on valid data in
# nss will work)
service nscd start
sleep 5 # give nscd time to initialize
EOF

    my $init_spma_ign_deps = "";
    $init_spma_ign_deps = "--ignore-errors-from-dependencies" if (
        $config->elementExists(INIT_SPMA_IGN_DEPS) &&
        $config->getElement (INIT_SPMA_IGN_DEPS)->getValue);

    print <<EOF;
/usr/sbin/ncm-ncd --verbose $init_spma_ign_deps --configure spma || fail "ncm-ncd --configure spma failed"
/usr/sbin/ncm-ncd --verbose --configure --all

EOF
}

sub kspostreboot_tail
{
    my $config = shift;

    ksuserscript ($config, POSTREBOOTSCRIPT);

    print <<EOF;

success

if [ -x /usr/bin/systemctl ]; then
    rm -f /etc/systemd/system/system-update.target.wants/ks-post-reboot.service
    rmdir --ignore-fail-on-non-empty /etc/systemd/system/system-update.target.wants
    rm -f /etc/systemd/system.conf.d/ks-post-reboot.conf
    rmdir --ignore-fail-on-non-empty /etc/systemd/system.conf.d
else
    rm -f /etc/rc.d/rc3.d/S86ks-post-reboot
fi

echo 'End of ks-post-reboot'

# Drain remote logger (0 if not relevant)
sleep \\\$drainsleep

if [ -x /usr/bin/systemctl ]; then
    /usr/bin/systemctl --no-wall reboot
else
    shutdown -r now
fi

EOF
}


# Prints the post_reboot script.
sub post_reboot_script
{
    my ($self, $config) = @_;

    kspostreboot_header ($config);
    ksuserhooks ($config, POSTREBOOTHOOK);
    ksquattor_config ($config);
    ksuserhooks ($config, POSTREBOOTENDHOOK);
    kspostreboot_tail ($config);
}

# The way Anaconda handles the bootloader and MBR can screw software
# RAID. This fixes it.
sub ksfix_grub
{
        print <<EOF;
BOOT_ARRAY=`df /boot | awk '/dev/{print \$1}'`
if [ -n "\$BOOT_ARRAY" ] ; then
    # Select only active disks (skip spares)
    case "\$BOOT_ARRAY" in
    /dev/md* )
        level=`mdadm --query \$BOOT_ARRAY|awk '/raid/ {print \$3}'`
        DISKS=`mdadm --query --detail \$BOOT_ARRAY | \\
               awk '/active sync/{print \$7}'| \\
               sed 's!/dev/!!g
                    s/,/ /g
                    s/[0-9]//g'`
        for d in \$DISKS
        do
            dpart=`mdadm --query --detail \$BOOT_ARRAY | \\
                   awk '/dev\\/'\$d'[0-9]/ {print \$7}'| \\
                   sed 's!/dev/'\$d'!!g'`
            dpart=`expr \$dpart - 1`
            eval PART_\$d=\$dpart
        done
        ;;
    /dev/sd*|/dev/hd*)
        DISKS=`echo "\$BOOT_ARRAY" | \\
               sed 's!/dev/!!g
                    s/,/ /g
                    s/[0-9]//g'`
        dpart=`echo "\$BOOT_ARRAY" | sed 's!/dev/'\$DISKS'!!g'`
        dpart=`expr \$dpart - 1`
        eval PART_\$DISKS=\$dpart
        ;;
    * )
        DISKS=""
        ;;
    esac

    i=0
    for d in \$DISKS
    do
        eval dpart=\\\$PART_\$d
        echo bootspec setting grub on /dev/\$d: to hd\$i,\$dpart
        cat <<EOGRUB | /sbin/grub --batch
device (hd\$i) /dev/\$d
root (hd\$i,\$dpart)
setup (hd\$i)
quit
EOGRUB

    # For raid1, hd number must be different for each member
    if [ -n "\$level" -a "\$level" = "raid1" ]
    then
      i=`expr \$i + 1`
    fi

    done
fi

# remove splash image as it breaks on Thumpers and is otherwise useless
sed -i '/splashimage/d' /boot/grub/grub.conf

# Restrict the ability to boot from only the first disks (hd0,
# hd1). Thumpers boot from sdac or sdy, but those are GRUB's hd0 and
# hd1.
perl -pi -e 's/hd(\\d+)/"hd".(\$1 > 1 ? 0:\$1)/e' /boot/grub/grub.conf

EOF
}


# match based on length of glob
# assuming the longest glob is the most specific
# return list of (glob, action_value) sorted on decreasing length of glob
#    -1: ignore
#    0: disable
#    1: enable
sub make_enable_disable_ignore_repo_filter {
    my ($config) = @_;

    my $ks = $config->getTree(KS);

    my %value_map = (
        ignore => -1,
        disable => 0,
        enable => 1,
    );

    my %filter = map {$_ => ($ks->{$_."d_repos"} || [])} qw(enable disable ignore);

    my @res = ();

    foreach my $action (sort keys %filter) {
        push(@res, map {[$_, $value_map{$action}]} @{$filter{$action}});
    }

    # reverse ordered length of glob sort
    return [sort {length($b->[0]) <=> length($a->[0])} @res]
};

# first match of filter wins
# return values
#    undef: no match -> continue
#    -1: ignore
#    0: disable
#    1: enable
sub enable_disable_ignore_repo {
    my ($name, $filter) = @_;

    foreach my $op (@$filter) {
        return $op->[1] if match_glob($op->[0], $name);
    }

    return undef;
}



# create repo information with baseurl and proxy settings
# return hashref with key the repo name
sub get_repos
{
    my ($config) = @_;

    my %res;

    unless ( $config->elementExists(REPO) ) {
      $this_app->error(REPO." not defined in configuration");
      return
    }

    my $repos = $config->getTree(REPO);

    my $filter = make_enable_disable_ignore_repo_filter($config);

    my $proxy = proxy($config);

    foreach my $repo (@$repos) {
        my $name = $repo->{name};
        my $edi = enable_disable_ignore_repo($name, $filter);
        if (defined($edi)) {
            if ($edi == -1) {
                $this_app->debug(5, "Ignore YUM repository $name");
                next;
            } else {
                $this_app->debug(5, 'Force ', ($edi ? 'enable' : 'disable'), " YUM repository $name");
                $repo->{enabled} = $edi;
            }
        }

        $repo->{protocols}->[0]->{url} = proxy_url($proxy, $repo->{protocols}->[0]->{url});

        $repo->{baseurl} = $repo->{protocols}->[0]->{url};

        # mandatory in 16.4 schema
        #   these values are the default values in the schema
        $repo->{enabled} = 1 if(! defined($repo->{enabled}));
        $repo->{gpgcheck} = 0 if(! defined($repo->{gpgcheck}));

        if (! $repo->{proxy} &&
            ($proxy->{type} || '') eq 'forward') {
            $repo->{proxy} = "http://$proxy->{host}:$proxy->{port}/";
        }

        $res{$name} = $repo;

    }

    return \%res;
}


# Given a string $txt and hashref $repos, replace any occurence of glob @pattern@ with matching
# repository converted in options. There can only be one glob.
# $baseurl_key is the optionname that is prefixed to the glob (--<baseurl_key>=<repo{baseurl}>)
#    unless it is not defined
# $opt_map is the optional mapping to the generated text appended at the end: --<key>=$repo{<value>}
# it returns a arrayref with all replaced text (empty list when there is a glob, but no repo was matched)
# noglob is an anonymous sub that is called on the original $txt when there is no glob present
#    this sub must return an arrayref
# If only_one_txt is defined, the result is checked if there is exactly one, and the text is used
#   to generate a warning
# returns undef when there is no match
sub replace_repo_glob
{
    my ($txt, $repos, $noglob, $baseurl_key, $opt_map, $only_one_txt) = @_;

    my $res;

    if ($txt =~ m/^([^@]*)@([^@]+)@([^@]*)$/) {
        $res = [];

        my $begin = $1;
        my $glob_pattern = $2;
        my $end = $3;

        # find at least one repo with matching name
        my @matches = match_glob($glob_pattern, sort keys %$repos);
        if (@matches) {
            foreach my $reponame (@matches) {
                my $repo = $repos->{$reponame};
                next if ! $repo->{enabled};

                my $txt = (defined($baseurl_key) ? "--$baseurl_key=" : '').$repo->{baseurl};

                my @opts;
                foreach my $key (sort keys %{$opt_map || {}}) {
                    my $val = $repo->{$opt_map->{$key}};
                    push(@opts, "--$key=". (ref($val) eq 'ARRAY' ? join(',', @$val) : $val)) if defined($val);
                }
                push(@$res, join(' ', "$begin$txt$end", @opts));
            }

            if ($only_one_txt && (scalar @$res > 1)) {
                $this_app->warn("$only_one_txt glob had more than one match.",
                                "Only using first match. All matches: ", join('|', @$res));
            };
            $this_app->debug(5, "replace_repo_glob: pattern $glob_pattern matches ", join(',', @matches),
                             " (from text $txt) with ", join('|', @$res));
        } else {
            $this_app->error("replace_repo_glob: no spma repositories that match $glob_pattern (from text $txt)");
        }
    } else {
        $res = $noglob->($txt);
    }

    return $res;
};

sub yum_setup
{
    my ($self, $config, $repos) = @_;

    $self->debug(5, "Configuring YUM repositories...");

    # SPMA_OBSOLETES doesn't exist in 13.1 , assume false by default
    my $obsoletes = 0;
    if ( $config->elementExists(SPMA_OBSOLETES) ) {
        $obsoletes = $config->getElement (SPMA_OBSOLETES)->getTree();
    }

    my $extra_yum_opts = {};
    if ( $config->elementExists(SPMA_YUMCONF) ) {
        $extra_yum_opts = $config->getElement (SPMA_YUMCONF)->getTree();
    }

    print <<EOF;
mkdir -p /var/tmp/aii/yum/repos
chmod 700 /var/tmp/aii
ln -s /var/tmp/aii /tmp/aii

cat <<end_of_yum_conf > /var/tmp/aii/yum/yum.conf
[main]
EOF

    my $default_opts = {
        cachedir => '/var/cache/yum/\$basearch/\$releasever',
        keepcache => 0,
        debuglevel => 2,
        logfile => '/var/log/yum.log',
        exactarch => 1,
        gpgcheck => 1,
        plugins => 1,
        installonly_limit => 3,
        clean_dependencies_on_remove => 1,
        reposdir => '/var/tmp/aii/yum/repos',
        obsoletes => $obsoletes,
    };

    my %opts = (%$default_opts, %$extra_yum_opts);

    foreach my $key (sort keys %opts) {
        my $v = $opts{$key};
        my $value = ref($v) eq 'ARRAY' ? join(($key eq 'exclude') ? ' ' : ',', @$v) : $v;
        print "$key=$value\n";
    };

    print <<EOF;
end_of_yum_conf

cat <<end_of_repos > /var/tmp/aii/yum/repos/aii.repo
EOF

    $self->debug(5, "Adding YUM repositories...");

    foreach my $name (sort keys %$repos) {
        my $repo = $repos->{$name};

        print <<EOF;
[$name]
name=$name
baseurl=$repo->{baseurl}
skip_if_unavailable=1
EOF
        if ($repo->{proxy}) {
            print "proxy=$repo->{proxy}\n";
        }

        # Handle inconsistent name mapping
        if ($repo->{excludepkgs}) {
            print "exclude=", join(' ', @{$repo->{excludepkgs}}), "\n";
        }

        # in line with 16.4 ncm-spma repository.tt
        # exception: skip_if_unavailable is forced to true above
        foreach my $opt (qw(enabled gpgcheck priority includepkgs repo_gpgcheck gpgcakey)) {
            if(defined($repo->{$opt})) {
                my $value = ref($repo->{$opt}) eq 'ARRAY' ? join(' ', @{$repo->{$opt}}) : $repo->{$opt};
                print "$opt=$value\n";
            }
        }

        if(defined($repo->{gpgkey})) {
            print "gpgkey=", join("\n    ", @{$repo->{gpgkey}}), "\n";
        }

    }

    print "end_of_repos\n";

    $self->debug(5,"    YUM repositories added...");
}

sub process_pkgs
{
    my ($self, $pkg, $ver) = @_;

    my @ret;
    if (%$ver) {
        foreach my $version (sort keys %$ver) {
            my $arch = $ver->{$version};
            my $p = sprintf("%s-%s", $pkg, unescape($version));
            if ($arch) {
                push(@ret, map("$p.$_", sort keys(%{$arch->{arch}})));
            } else {
                push(@ret, $p);
            }
        }
    } else {
        push(@ret, $pkg);
    }
    return @ret;
}

# C<simple_version_glob> will select all version-locked packages, if any.
# Then, all non-locked packages that match the locked non-versioned
# packages glob are removed. Finally, all remaining non-locked
# packages are added.
#
# E.g. "yum install kernel*-X.Y.Z kernel-firmware" will try to install
# the latest kernel-firmware with a set of fixed kernel rpms,
# probably not matching with latest kernel-firmware version
# Ideally, kernel*-X.Y.Z is defined in the profile, and no other
# kernel packages are version locked.
sub simple_version_glob {
    my ($self, @pkglist) = @_;
    my @res;
    my @locked;
    my %pkgs;
    foreach my $ref (@pkglist) {
        my ($pkgst, $st) = @$ref;
        my @processed = $self->process_pkgs($pkgst, $st);
        $pkgs{$pkgst} = \@processed;

        # test if certain pkg is version locked
        # (specifying arch is also considered locking)
        # it's sufficient to the test first element
        # (you can't mix locked and unlocked)
        push(@locked, $pkgst) if ($processed[0] !~ m/^$pkgst$/);
    };

    foreach my $locked_pkg (@locked) {
        # add it to res
        push(@res, @{delete $pkgs{$locked_pkg}});
    }

    # get rid of packages matching the non-versioned glob of
    # locked packages
    foreach my $locked_pkg (@locked) {
        foreach my $globmatch (match_glob($locked_pkg, keys %pkgs)) {
            delete $pkgs{$globmatch} ;
        };
    };

    # add remainder unlocked non-matching packages
    foreach my $key (sort keys %pkgs) {
        push (@res, @{$pkgs{$key}}) ;
    };
    return @res;
}


sub yum_install_packages
{
    my ($self, $config, $packages) = @_;

    $self->debug(5, "Adding packages to install with YUM...");

    my @pkgs;
    my $pkgtree = $config->getTree(PKG);
    my $ks = $config->getTree(KS);

    my %base = map(($_ => 1), @{$ks->{base_packages}});


    my @install = ("ncm-spma", "ncm-grub");
    push(@install, "kernel") if $ks->{kernelinpost};
    my $pattern = '^('.join('|', @install).')';

    print <<EOF;
# This one will be reinstalled by Yum in the correct version for our
# kernels.
rpm -e --nodeps kernel-firmware
# This one may interfere with the versions of Yum required on SL5.  If
# it's needed at all, it will be reinstalled by the SPMA component.
rpm -e --nodeps yum-conf
EOF
    foreach my $pkg (sort keys %$pkgtree) {
        my $pkgst = unescape($pkg);
        if ($pkgst =~ m{$pattern} || exists($base{$pkgst})) {
            push (@pkgs, [$pkgst, $pkgtree->{$pkg}]);
        }
    }

    my @yumpkgs;
    if ($packages) {
        # packages are installed unconditionally,
        # not checked like basepackages
        push(@yumpkgs, @$packages);
    }
    push(@yumpkgs, $self->simple_version_glob(@pkgs));
    $self->debug(5, "    Adding YUM commands to install " . join(",", @yumpkgs));
    ksinstall_rpm($config, @yumpkgs);

    $self->debug(5, "Packages to install added...");
}

# Prints the %post script. The post_reboot script is created inside
# this method.
sub post_install_script
{
    my ($self, $config, $packages, $repos) = @_;

    my $tree = $config->getElement (KS)->getTree;
    my $version = get_anaconda_version($tree);

    $self->debug(5, "Adding postinstall script...");

    my $logfile = '/tmp/post-log.log';
    my $logaction = log_action($config, $logfile);

    print <<EOF;

%post --nochroot

test -f /tmp/pre-log.log && cp -a /tmp/pre-log.log /mnt/sysimage/root/
EOF

    ksuserhooks ($config, POSTNOCHROOTHOOK);

    print <<EOF;

%end

%post

# %post phase. The base system has already been installed. Let's do
# some minor changes and prepare it for being configured.
$logaction

chmod 600 $logfile

echo 'Begin of post section'
set -x


EOF

    $self->kspostreboot_hereopen;
    $self->post_reboot_script ($config);
    $self->kspostreboot_hereclose;
    ksuserhooks ($config, POSTHOOK);

    if (exists $tree->{selinux} && $tree->{selinux} eq 'disabled') {
        print "\n# Disable selinux via kernel parameter\ngrubby --update-kernel=DEFAULT --args=selinux=0\n";
    };

    $self->yum_setup ($config, $repos);
    $self->yum_install_packages ($config, $packages);
    ksuserscript ($config, POSTSCRIPT);

    # TODO what is this supposed to solve? it needs to be retested on EL70+
    # in any case, no grub on EL70+
    if ($tree->{bootloader_location} eq "mbr" && $version < ANACONDA_VERSION_EL_7_0) {
        ksfix_grub;
    }

    # restore UEFI pxeboot first
    if ($tree->{pxeboot}) {
        print <<EOF;
#
# restore pxeboot as first boot order in case efibootmgr is around
#
efibootmgr=/usr/sbin/efibootmgr
if [ -x \$efibootmgr ]; then
    boot_current=\$(\$efibootmgr -v | grep BootCurrent | cut -d' ' -f2-)
    boot_order=\$(\$efibootmgr -v | grep BootOrder | cut -d' ' -f2-)
    first_boot_nr_hex=\$(echo \${boot_order} | awk -F, '{print \$1}')

    if [ "\${first_boot_nr_hex}" != "\${boot_current}" ]
    then
        new_boot_order=\${boot_current}
        for entry in \$(echo \$boot_order | sed -e 's/,/ /g')
        do
            if [ \${entry} != \${boot_current} ]
            then
                new_boot_order="\$new_boot_order,\${entry}"
            fi
        done

        echo "Setting entry  \${boot_current} first in boot order list"
        \$efibootmgr -o "\$new_boot_order" -q
        echo "New boot order: \$(\$efibootmgr -v | grep BootOrder | cut -d' ' -f2-)"
    fi
fi

EOF
    }

    # delete services, if any
    # on EL7 the services disabled via the kickstart commands only
    if ($tree->{disable_service} && $version < ANACONDA_VERSION_EL_7_0) {
        ## should be a list of strings
        my $services = join(" ",@{$tree->{disable_service}});
        if ($services) {
            print <<EOF;
#
# disable services (if they exist)
#
for SERVICE in $services
do
/sbin/chkconfig --list \$SERVICE
if [ \$? -eq 0 ]
then
    /sbin/chkconfig --del \$SERVICE
fi
done

EOF
        };
    };

    # Systemd unit file
    #   Targets
    #     basic.target is default dependency
    #     we need network.target
    #       and ks-post-reboot needs to be started after it (not in parallel)
    #     syslog/rsyslog and sshd are a nice-to-have
    #   Type oneshot disables timeout and is blocking
    #     other services/targets can be started in parallel

    print <<EOF;

chmod +x /etc/rc.d/init.d/ks-post-reboot

if [ -x /usr/bin/systemctl ]; then
    cat <<EOF_reboot_unit > /usr/lib/systemd/system/ks-post-reboot.service
[Unit]
Description=Quattor AII Post reboot
DefaultDependencies=no
Requires=sysinit.target
Requires=network.target
After=sysinit.target
After=system-update-pre.target
After=systemd-journald.socket
After=network.target
After=network-online.target
After=network.service
Before=shutdown.target
Before=system-update.target
Before=system-update-cleanup.service
Wants=network-online.target
Wants=network.service

[Service]
Type=oneshot
ExecStart=/etc/rc.d/init.d/ks-post-reboot start
ExecStop=/bin/true
ExecStopPost=/usr/bin/rm -fv /system-update
FailureAction=reboot
TimeoutSec=18000
KillMode=control-group
KillSignal=SIGKILL
StandardInput=tty
TTYPath=/dev/console
TTYReset=yes
TTYVHangup=yes
EOF_reboot_unit

    # /system-update is expected to be a symlink, identifying which update script to run
    ln -sf /etc/rc.d/init.d/ks-post-reboot /system-update

    # The documentation recommends creating the .wants symlink directly instead of using [Install] and 'systemctl enable'
    mkdir -p /etc/systemd/system/system-update.target.wants
    ln -s /usr/lib/systemd/system/ks-post-reboot.service /etc/systemd/system/system-update.target.wants/

    # systemd debugging is a tricky business, so make it verbose during the first boot, just in case
    mkdir -p /etc/systemd/system.conf.d
    cat <<EOF_systemd_logging > /etc/systemd/system.conf.d/ks-post-reboot.conf
[Manager]
LogLevel=debug
EOF_systemd_logging

else
    ln -s /etc/rc.d/init.d/ks-post-reboot /etc/rc.d/rc3.d/S86ks-post-reboot
fi

EOF

    my @acklist;
    if ($config->elementExists (ACKLIST) ) {
        @acklist = @{$config->getElement (ACKLIST)->getTree()};
    } else {
        @acklist = ($config->getElement (ACKURL)->getValue);
    }

    foreach my $url (@acklist) {
        print <<EOF;
wget -q --output-document=- '$url'
EOF
    }

    ksuserhooks ($config, PREREBOOTHOOK);
    print <<EOF;
echo 'End of post section'

# Drain remote logger (0 if not relevant)
sleep \$drainsleep

%end

EOF

}

# Closes the Kickstart file and returns everything to its normal
# state.
sub ksclose
{
    my $fh = select;
    select (STDOUT);
    $fh->close();
}

# Prints the kickstart file.
sub Configure
{
    my ($self, $config) = @_;

    my $fqdn = get_fqdn($config);
    if ($CAF::Object::NoAction) {
        $self->info ("Would run " . ref ($self) . " on $fqdn");
        return 1;
    }

    $self->ksopen ($config);
    my ($packages, $repos) = $self->install ($config);
    $self->pre_install_script ($config);
    $self->post_install_script ($config, $packages, $repos);
    $self->ksclose;
    return 1;
}

# Removes the KS file. To be called by --remove.
sub Unconfigure
{
    my ($self, $config) = @_;

    my $fqdn = get_fqdn($config);
    if ($CAF::Object::NoAction) {
        $self->info ("Would run " . ref ($self) . " on $fqdn");
        return 1;
    }

    my $ksdir = $main::this_app->option (KSDIROPT);
    unlink ("$ksdir/$fqdn.ks");
    return 1;
}
