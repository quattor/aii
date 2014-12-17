# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}


package NCM::Component::ks;

use strict;
use warnings;
use version;
use NCM::Component;
use EDG::WP4::CCM::Property;
use EDG::WP4::CCM::Element qw (unescape);
use NCM::Filesystem;
use NCM::Partition qw (partition_compare);
use NCM::BlockdevFactory qw (build);
use FileHandle;
use LC::Exception qw (throw_error);
use Data::Dumper;
use Exporter;
use CAF::FileWriter;
use Sys::Hostname;
use Text::Glob qw(match_glob);

our @ISA = qw (NCM::Component Exporter);
our $EC = LC::Exception::Context->new->will_store_all;

our $this_app = $main::this_app;
# Modules that may be interesting for hooks.
our @EXPORT_OK = qw (ksuserhooks ksinstall_rpm);

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
               POSTHOOK         => "/system/aii/hooks/post_install",
               ANACONDAHOOK     => "/system/aii/hooks/anaconda",
               PREREBOOTHOOK    => "/system/aii/hooks/pre_reboot",
               PKG              => "/software/packages/",
               ACKURL           => "/system/aii/osinstall/ks/ackurl",
               ACKLIST          => "/system/aii/osinstall/ks/acklist",
               CARDS            => "/hardware/cards/nic",
               SPMAPROXY        => "/software/components/spma/proxy",
               SPMA             => "/software/components/spma",
               SPMA_OBSOLETES   => "/software/components/spma/process_obsoletes",
               ROOTMAIL         => "/system/rootmail",
               AII_PROFILE      => "/system/aii/osinstall/ks/node_profile",
               CCM_PROFILE      => "/software/components/ccm/profile",
               CCM_TRUST        => "/software/components/ccm/trust",
               CCM_KEY          => "/software/components/ccm/key_file",
               CCM_CERT         => "/software/components/ccm/cert_file",
               CCM_CA           => "/software/components/ccm/ca_file",
               CCM_WORLDR       => "/software/components/ccm/world_readable",
               CCM_DBFORMAT     => "/software/components/ccm/dbformat",
               EMAIL_SUCCESS    => "/system/aii/osinstall/ks/email_success",
               NAMESERVER       => "/system/network/nameserver/0",
               FORWARDPROXY     => "forward",
               END_SCRIPT_FIELD => "/system/aii/osinstall/ks/end_script",
               BASE_PKGS        => "/system/aii/osinstall/ks/base_packages",
               DISABLED_REPOS   => "/system/aii/osinstall/ks/disabled_repos",
               LOCALHOST        => hostname(),
           };

# Base package path for user hooks.
use constant   MODULEBASE       => "AII::";
use constant   USEMODULE        => "use " . MODULEBASE;

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

    my $dev = $config->getElement("/system/aii/nbp/pxelinux/ksdevice")->getValue;

    if ($dev =~ m!(?:[0-9a-f]{2}(?::[0-9a-f]{2}){5})|bootif|link!i) {
        $this_app->error("Invalid ksdevice $dev for static ks configuration.");
        return;
    }
    
    if (! $config->elementExists("/system/network/interfaces/$dev")) {
        $this_app->error("ksdevice $dev missing network details for static ks configuration.");
        return;
    }
    
    my $net = $config->getElement("/system/network/interfaces/$dev")->getTree;

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
        my $intfs = $config->getElement("/system/network/interfaces")->getTree;
        $net = $intfs->{$bonddev};
        
        # gather the slaves, the ksdevice is put first 
        my @slaves;
        push(@slaves, $dev);
        foreach my $intf (sort keys %$intfs) {
            push (@slaves, $intf) if ($intfs->{$intf}->{master} && 
                                      $intfs->{$intf}->{master} eq $bonddev &&
                                      !(grep { $_ eq $intf } @slaves));
        };

        push(@networkopts, "--bondslaves=".join(',', @slaves));

        # gather the options
        if ($net->{bonding_opts}) {
            my @opts;
            while (my ($k, $v) = each(%{$net->{bonding_opts}})) {
                push(@opts, "$k=$v");
            }
            push(@networkopts, "--bondopts=".join(',', @opts));
        }
        
        # continue with the bond device as network device
        $dev = $bonddev;
        
    }
    
    return ($dev, $net, @networkopts);

}    


# Configures the network, allowing both DHCP and static boots.
sub ksnetwork
{
    my ($tree, $config) = @_;

    my @network = qw(network);

    if ($tree->{bootproto} eq 'dhcp') {
        # TODO: no boot device selection with dhcp (e.g. needed for bonding)
        # Although fully supported in ks and easy to add, 
        # the issue here is backwards compatibilty (a.k.a. very old behaviour)
        $this_app->debug (5, "Node configures its network via DHCP");
        push(@network, "--bootproto=dhcp");
        return @network;
    }

    push(@network, "--bootproto=static");

    my ($dev, $net, @networkopts) = ksnetwork_get_dev_net($tree, $config);
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
    if ($net->{bridge}) {
        my $brdev = $net->{bridge}; 
        $this_app->debug (5, "Device $dev is a bridge interface for bridge $brdev.");
        # continue with network settings for the bridge device
        $net = $config->getElement("/system/network/interfaces/$brdev")->getTree;
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
sub ksuserhooks
{
    my ($config, $path) = @_;

    return unless $config->elementExists ($path);

    $this_app->debug (5, "User defined hooks for $path");
    my $el = $config->getElement ($path);
    $path =~ m(/system/aii/hooks/([^/]+));
    my $method = $1;
    while ($el->hasNextElement) {
        my $nel = $el->getNextElement;
        my $tree = $nel->getTree;
        my $nelpath = $nel->getPath->toString;
        # Catch bad guys
        if ($tree->{module} !~ m/^[_a-zA-Z]\w+$/) {
            $this_app->error ("Invalid identifier specified as a hook module. ",
                              "Skipping");
            next;
        }
        my $modulename = MODULEBASE . $tree->{module};
        $this_app->debug (5, "Loading " . $modulename);
        eval ("use " . $modulename);
        if ($@) {
            # Fallback: try without the AII:: prefix
            my $orig_error = $@;
            $modulename = $tree->{module};
            $this_app->debug (5, "Loading " . $modulename);
            eval ("use " . $modulename);
            # Report the original error message if the fallback failed
            throw_error ("Couldn't load module $tree->{module}: $orig_error")
                if $@;
        }
        my $hook = eval ($modulename . "->new");
        throw_error ("Couldn't instantiate object of class $tree->{module}")
          if $@;
        $this_app->debug (5, "Running $tree->{module}->$method");
        $hook->$method ($config, $nelpath);
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
    
    my $installtype = $tree->{installtype};
    if ($installtype =~ /http/) {
        my ($proxyhost, $proxyport, $proxytype) = proxy($config);
        if ($proxyhost) {
            if ($proxyport) {
                $proxyhost .= ":$proxyport";
            }
            if ($proxytype eq "reverse") {
                $installtype =~ s{(https?)://([^/]*)/}{$1://$proxyhost/};
            }
        }
    }
    
    print <<EOF;
install
$installtype
reboot
timezone --utc $tree->{timezone}
rootpw --iscrypted $tree->{rootpw}
EOF

    if ($tree->{repo}) {
        print "repo $_ \n" foreach @{$tree->{repo}};
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
    if ($tree->{clearmbr}) {
        print "zerombr", $version >= ANACONDA_VERSION_EL_7_0 ? "" : " yes", "\n";
    }
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
    if ($tree->{packagesinpost}) {
        # to be installed later in %post using all repos
        print "\n";
        $unprocessed_packages = \@packages;
    } else {
        print " ", join(" ",@{$tree->{packages_args}}), "\n",
            join ("\n", @packages), "\n";
    }
    print $version >= ANACONDA_VERSION_EL_6_0 ? $config->getElement(END_SCRIPT_FIELD)->getValue() : '', 
          "\n";
    return $unprocessed_packages;    

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
        my $fstree = NCM::Filesystem->new ($fs->getPath->toString,
                                           $config);
        next if ($fstree->{block_device}->{holding_dev} &&
                 $ignoredisk{$fstree->{block_device}->{holding_dev}->{devname}});
        $this_app->debug (5, "Pre-processing filesystem $fstree->{mountpoint}");

        # EL7+ anaconda does not allow a preformatted / filesystem
        if ($version >= ANACONDA_VERSION_EL_7_0 && 
                $fstree->{mountpoint} eq '/' && 
                ! $fstree->{ksfsformat}) {
            $fstree->{ksfsformat}=1;
        }
        
        $fstree->print_ks;
    }
}

# Prints the code for downloading and executing an user script.
sub ksuserscript
{
    my ($config, $path) = @_;

    return unless $config->elementExists ($path);
    my $url = $config->getElement ($path)->getValue;
    $this_app->debug (5, "User defined script to be fetched ",
                      "from $url for path $path");

    print <<EOS;
pushd /root
wget --output-document=userscript $url
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

    my $packages = kscommands ($config);
    
    return $packages;
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
        push(@logactions, '# Make sure messages show up on the serial console',
                          "tail -f $logfile > /dev/console &");
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

    print <<'EOF';

# Hack for RHEL 6: force re-reading the partition table
#
# fdisk often fails to re-read the partition table on RHEL 6, so we have to do
# it explicitely. We also have to make sure that udev had enough time to create
# the device nodes.
rereadpt () {
    [ -x /sbin/udevadm ] && udevadm settle
    # hdparm can still fail with EBUSY without the wait...
    sleep 2
    hdparm -q -z "$1"
    [ -x /sbin/udevadm ] && udevadm settle
    # Just in case...
    sleep 2
}

# Align the start of a partition
align () {
    local disk path n align_sect START ALIGNED
    # By passing disk/path/n separately, we don't have to worry about part_prefix
    disk="$1"
    path="$2"
    n="$3"
    align_sect="$4"

    START=`fdisk -ul $disk | awk '{if ($1 == "'$path'") print $2 == "*" ? $3: $2}'`
    ALIGNED=$((($START + $align_sect - 1) / $align_sect * $align_sect))
    if [ $START != $ALIGNED ]; then
        echo "-----------------------------------"
        echo "Aligning $path: old start sector: $START, new: $ALIGNED"
        fdisk $disk <<end_of_fdisk
x
b
$n
$ALIGNED
w
end_of_fdisk

        rereadpt $disk
    fi
}

wipe_metadata () {
    local path clear SIZE ENDSEEK ENDSEEK_OFFSET
    path="$1"
	ENDSEEK_OFFSET=20
    # try to get the size with fdisk
    SIZE=`fdisk -lu "$path" |grep total|grep sectors|awk -F ' ' '{print $8}'`
    # if empty, assume we failed and try with parted
    if [ -z $SIZE ]; then
        SIZE=`parted "$path" -s -- u s p | grep "Disk $path" |awk '{print substr($3, 0, length($3)-1)}'`
        # if at this point the SIZE has not been determined, 
        # set it equal to ENDSEEK_OFFSET, the entire disk gets wiped. 
        if [ -z $SIZE ]; then
            SIZE=$ENDSEEK_OFFSET
            echo "[WARN] Could not determine the size of device $path with both fdisk and parted. Wiping whole drive instead"
        fi
    fi
    let ENDSEEK=$SIZE-$ENDSEEK_OFFSET
    echo "[INFO] wipe path $path with SIZE $SIZE and ENDSEEK $ENDSEEK"
    dd if=/dev/zero of="$path" bs=512 count=10 2>/dev/null
    dd if=/dev/zero of="$path" bs=512 seek=$ENDSEEK 2>/dev/null
}

EOF

    # Hook handling should come here, to allow NIKHEF to override
    # partitioning.
    ksuserhooks ($config, PREHOOK);

    $self->ksprint_filesystems ($config);
    # Is this needed if we are allowing for hooks?
    ksuserscript ($config, PRESCRIPT);

    ksuserhooks ($config, PREENDHOOK);

    my $end = $config->getElement(END_SCRIPT_FIELD)->getValue();

    print <<EOF;

# De-activate logical volumes. Needed on RHEL6, see:
# https://bugzilla.redhat.com/show_bug.cgi?id=652417
lvm vgchange -an
echo 'End of pre section'

# Drain remote logger (0 if not relevant)
sleep \$drainsleep

$end

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

    foreach (@$clear) {
        my $disk = build ($config, "physical_devs/".$self->escape($_));
        $disk->clearpart_ks;
    }
    while ($fss->hasNextElement) {
        my $fs = $fss->getNextElement;
        my $fstree = NCM::Filesystem->new ($fs->getPath->toString,
                                           $config);
        $fstree->del_pre_ks;
        push (@filesystems, $fstree);
    }

    # Create what needs to be created.
    $fss = $config->getElement (PART);
    my @part = ();
    while ($fss->hasNextElement) {
        my $p = $fss->getNextElement;
        my $pt = NCM::Partition->new ($p->getPath->toString,
                                      $config);

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
    $_->create_pre_ks foreach (sort partition_compare @part);
    foreach (sort partition_compare @part) {
        $_->align_ks if $_->can('align_ks');
    }
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

    # DISABLED_REPOS doesn't exist in 13.1 
    my $disabled = [];
    if ( $config->elementExists(DISABLED_REPOS) ) {
        $disabled = $config->getElement(DISABLED_REPOS)->getTree();
    }
    my $cmd = "yum -c /tmp/aii/yum/yum.conf -y install ";

    $cmd .= " --disablerepo=" . join(",", @$disabled) . " " if @$disabled;

    print $cmd, join("\\\n    ", @pkgs),
         "|| fail 'Unable to install packages'\n";
}

sub proxy
{
    my ($config) = @_;
    my ($proxyhost, $proxyport, $proxytype);
    if ($config->elementExists (SPMAPROXY)) {
        my $spma = $config->getElement (SPMA)->getTree;
        my $proxy_host = $spma->{proxyhost};
        my @proxies = split /,/,$proxy_host;
        if (scalar(@proxies) == 1) {
            # there's only one proxy specified
            $proxyhost = $spma->{proxyhost};
        } elsif (scalar(@proxies) > 1) {
            # optimize by picking the responding server as the proxy
            my ($me) = grep { /\b@(LOCALHOST)\b/ } @proxies;
            $me ||= $proxies[0];
            $proxyhost = $me;
        }
        if ($spma->{proxyport}) {
            $proxyport = $spma->{proxyport};
        }
        if ($spma->{proxytype}) {
            $proxytype = $spma->{proxytype};
        }
    }
    return ($proxyhost, $proxyport, $proxytype);
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

    print <<EOF;
#!/bin/bash
# Script to run at the first reboot. It installs the base Quattor RPMs
# and runs the components needed to get the system correctly
# configured.

hostname $fqdn

# Function to be called if there is an error in this phase.
# It sends an e-mail to $rootmail alerting about the failure.
fail() {
    echo "Quattor installation on $fqdn failed: \\\$1"
    sendmail -t <<End_of_sendmail
From: root\@$fqdn
To: $rootmail
Subject: [\\`date +'%x %R %z'\\`] Quattor installation on $fqdn failed: \\\$1

\\`cat $logfile\\`
------------------------------------------------------------
\\`ls -tr /var/log/ncm 2>/dev/null|xargs tail /var/log/spma.log\\`

.
End_of_sendmail
    # Drain remote logger (0 if not relevant)
    sleep \\\$drainsleep
    exit 1
}

# Function to be called if the installation succeeds.  It sends an
# e-mail to $rootmail alerting about the installation success.
success() {
    echo "Quattor installation on $fqdn succeeded"
    sendmail -t <<End_of_sendmail
From: root\@$fqdn
To: $rootmail
Subject: [\\`date +'%x %R %z'\\`] Quattor installation on $fqdn succeeded

Node $fqdn successfully installed.
.
End_of_sendmail
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

    # Hack to prevent ncm-network failing when the order of interfaces does not
    # match its expectations
    my $clear_netcfg = 0;
    if ($config->elementExists("/system/network/set_hwaddr") &&
            $config->getElement("/system/network/set_hwaddr")->getValue &&
            $config->elementExists("/system/aii/nbp/pxelinux/ksdevicemode") &&
            $config->getElement("/system/aii/nbp/pxelinux/ksdevicemode")->getValue eq 'mac') {
        $clear_netcfg = 1;
    }

    print <<EOF;

# SPMA transactions may open HUGE amounts of files at the same time.
ulimit -n 8192

cat <<End_Of_CCM_Conf > /etc/ccm.conf
# Base configuration for CCM
# Generated by AII Kickstart Generator
EOF

    if ($config->elementExists (AII_PROFILE)) {
        print "profile ", $config->getElement (AII_PROFILE)->getValue, "\n";
    } else {
        print "profile ", $config->getElement (CCM_PROFILE)->getValue, "\n";
    }
    print "key_file ", $config->getElement (CCM_KEY)->getValue, "\n"
      if $config->elementExists (CCM_KEY);
    print "cert_file ", $config->getElement (CCM_CERT)->getValue, "\n"
      if $config->elementExists (CCM_CERT);
    print "ca_file ",  $config->getElement (CCM_CA)->getValue, "\n"
      if $config->elementExists (CCM_CA);
    print "world_readable ", $config->getElement (CCM_WORLDR)->getValue, "\n"
      if $config->elementExists (CCM_WORLDR);
    print "dbformat ", $config->getElement (CCM_DBFORMAT)->getValue, "\n"
      if $config->elementExists (CCM_DBFORMAT);
    print "trust ", $config->getElement (CCM_TRUST)->getValue, "\n"
      if $config->elementExists (CCM_TRUST);
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

    if ($clear_netcfg) {
        # TODO adjust the eth* glob to also delete lots of other devices?
        print <<EOF;
rm -f /etc/udev.d/rules.d/70-persistent-net.rules
rm -f /etc/sysconfig/network-scripts/ifcfg-eth*
EOF
    }

    print <<EOF;
/usr/sbin/ncm-ncd --verbose --configure spma || fail "ncm-ncd --configure spma failed"
/usr/sbin/ncm-ncd --verbose --configure --all

EOF
}

sub kspostreboot_tail
{
    my $config = shift;

    ksuserscript ($config, POSTREBOOTSCRIPT);
    print "\nsuccess\n" if $config->elementExists (EMAIL_SUCCESS) &&
      $config->getElement (EMAIL_SUCCESS)->getTree;

    print <<EOF;
rm -f /etc/rc.d/rc3.d/S86ks-post-reboot
echo 'End of ks-post-reboot'

# Drain remote logger (0 if not relevant)
sleep \\\$drainsleep

shutdown -r now

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


sub yum_setup
{
    my ($self, $config) = @_;

    $self->debug(5,"Configuring YUM repositories...");

    # SPMA_OBSOLETES doesn't exist in 13.1 , assume false by default
    my $obsoletes = 0;
    if ( $config->elementExists(SPMA_OBSOLETES) ) {
        $obsoletes = $config->getElement (SPMA_OBSOLETES)->getTree();
    }
    my $repos;
    unless ( $config->elementExists(REPO) ) {
      $this_app->error(REPO." not defined in configuration");
      return
    } 
    $repos = $config->getElement (REPO)->getTree();

    print <<EOF;
mkdir -p /tmp/aii/yum/repos
cat <<end_of_yum_conf > /tmp/aii/yum/yum.conf
[main]
cachedir=/var/cache/yum/\$basearch/\$releasever
keepcache=0
debuglevel=2
logfile=/var/log/yum.log
exactarch=1
gpgcheck=1
plugins=1
installonly_limit=3
clean_dependencies_on_remove=1
reposdir=/tmp/aii/yum/repos
obsoletes=$obsoletes
end_of_yum_conf

cat <<end_of_repos > /tmp/aii/yum/repos/aii.repo
EOF

    my ($phost, $pport, $ptype) = proxy($config);

    $self->debug(5,"    Adding YUM repositories...");

    foreach my $repo (@$repos) {
        if ($ptype && $ptype eq 'reverse') {
            $repo->{protocols}->[0]->{url} =~ s{://[^/]*}{://$phost:$pport};
        }
        print <<EOF;
[$repo->{name}]
enabled=1
baseurl=$repo->{protocols}->[0]->{url}
name=$repo->{name}
gpgcheck=0
skip_if_unavailable=1
EOF
        if ($repo->{proxy}) {
            print <<EOF;
proxy=$repo->{proxy}
EOF
        } elsif ($ptype && $ptype eq 'forward') {
            print <<EOF;
proxy=http://$phost:$pport/
EOF
        }

        if ($repo->{priority}) {
            print <<EOF;
priority=$repo->{priority}
EOF
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
        while (my ($version, $arch) = each(%$ver)) {
            my $p = sprintf("%s-%s", $pkg, unescape($version));
            if ($arch) {
                push(@ret, map("$p.$_", keys(%{$arch->{arch}})));
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
    foreach my $ref (values %pkgs) {
        push (@res, @$ref) ;
    };
    return @res;    
}


sub yum_install_packages
{
    my ($self, $config, $packages) = @_;

    $self->debug(5,"Adding packages to install with YUM...");

    my @pkgs;
    my $t = $config->getElement (PKG)->getTree();
    
    my %base = map(($_ => 1), @{$config->getElement (BASE_PKGS)->getTree()});

    print <<EOF;
# This one will be reinstalled by Yum in the correct version for our
# kernels.
rpm -e --nodeps kernel-firmware
# This one may interfere with the versions of Yum required on SL5.  If
# it's needed at all, it will be reinstalled by the SPMA component.
rpm -e --nodeps yum-conf
EOF
    while (my ($pkg, $st) = each(%$t)) {
        my $pkgst = unescape($pkg);
        if ($pkgst =~ m{^(kernel|ncm-spma|ncm-grub)} || exists($base{$pkgst})) {
            push (@pkgs, [$pkgst, $st]);
        }
    }

    my @yumpkgs;
    if ($packages) {
        # packages are installed unconditionally, 
        # not checked like basepackages
        push(@yumpkgs, @$packages);    
    }
    push(@yumpkgs, $self->simple_version_glob(@pkgs));
    $self->debug(5,"    Adding YUM commands to install ".join(",",@pkgs));
    ksinstall_rpm($config, @yumpkgs);

    $self->debug(5,"Packages to installi added...");
}

# Prints the %post script. The post_reboot script is created inside
# this method.
sub post_install_script
{
    my ($self, $config, $packages) = @_;

    my $tree = $config->getElement (KS)->getTree;
    my $version = get_anaconda_version($tree);

    $self->debug(5,"Adding postinstall script...");

    my $logfile='/tmp/post-log.log';
    my $logaction = log_action($config, $logfile);

    print <<EOF;

%post

# %post phase. The base system has already been installed. Let's do
# some minor changes and prepare it for being configured.
$logaction
echo 'Begin of post section'
set -x


EOF

    $self->kspostreboot_hereopen;
    $self->post_reboot_script ($config);
    $self->kspostreboot_hereclose;
    ksuserhooks ($config, POSTHOOK);

    $self->yum_setup ($config);
    $self->yum_install_packages ($config, $packages);
    ksuserscript ($config, POSTSCRIPT);

    # TODO what is this supposed to solve? it needs to be retested on EL70+
    # in any case, no grub on EL70+
    if ($tree->{bootloader_location} eq "mbr" && $version < ANACONDA_VERSION_EL_7_0) {
        ksfix_grub;
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

    print <<EOF;

chmod +x /etc/rc.d/init.d/ks-post-reboot
ln -s /etc/rc.d/init.d/ks-post-reboot /etc/rc.d/rc3.d/S86ks-post-reboot
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
    my $end = $config->getElement(END_SCRIPT_FIELD)->getValue();
    print <<EOF;
echo 'End of post section'

# Drain remote logger (0 if not relevant)
sleep \$drainsleep

$end

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
    if ($NoAction) {
        $self->info ("Would run " . ref ($self) . " on $fqdn");
        return 1;
    }

    $self->ksopen ($config);
    my $packages = $self->install ($config);
    $self->pre_install_script ($config);
    $self->post_install_script ($config, $packages);
    $self->ksclose;
    return 1;
}

# Removes the KS file. To be called by --remove.
sub Unconfigure
{
    my ($self, $config) = @_;

    my $fqdn = get_fqdn($config);
    if ($NoAction) {
        $self->info ("Would run " . ref ($self) . " on $fqdn");
        return 1;
    }

    my $ksdir = $main::this_app->option (KSDIROPT);
    unlink ("$ksdir/$fqdn.ks");
    return 1;
}
