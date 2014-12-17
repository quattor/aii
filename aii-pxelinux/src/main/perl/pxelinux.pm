# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}

package NCM::Component::pxelinux;

use strict;
use warnings;
use version;
use NCM::Component;
use EDG::WP4::CCM::Property;
use NCM::Check;
use Sys::Hostname;
use CAF::FileWriter;
use NCM::Component::ks qw (ksuserhooks);
use LC::Fatal qw (symlink);
use File::stat;
use Time::localtime;
use Readonly;

use constant PXEROOT => "/system/aii/nbp/pxelinux";
use constant NBPDIR => 'nbpdir';
use constant LOCALBOOT => 'bootconfig';
use constant HOSTNAME => "/system/network/hostname";
use constant DOMAINNAME => "/system/network/domainname";
use constant ETH => "/system/network/interfaces";
use constant INSTALL => 'install';
use constant BOOT => 'boot';
use constant RESCUE => 'rescue';
use constant RESCUEBOOT => 'rescueconfig';
use constant FIRMWARE => 'firmware';
use constant LIVECD => 'livecd';
# Hooks for NBP plug-in
use constant RESCUE_HOOK_PATH => '/system/aii/hooks/rescue';
use constant INSTALL_HOOK_PATH => '/system/aii/hooks/install';
use constant REMOVE_HOOK_PATH => '/system/aii/hooks/remove';
use constant BOOT_HOOK_PATH => '/system/aii/hooks/boot';
use constant FIRMWARE_HOOK_PATH => '/system/aii/hooks/firmware';
use constant LIVECD_HOOK_PATH => '/system/aii/hooks/livecd';
# Kickstart constants (trying to use same name as in ks.pm from aii-ks)
use constant KS => "/system/aii/osinstall/ks";

# Lowest supported version is EL 5.0
use constant ANACONDA_VERSION_EL_5_0 => version->new("11.1");
use constant ANACONDA_VERSION_EL_6_0 => version->new("13.21");
use constant ANACONDA_VERSION_EL_7_0 => version->new("19.31"); 
use constant ANACONDA_VERSION_LOWEST => ANACONDA_VERSION_EL_5_0;

our @ISA = qw (NCM::Component);
our $EC = LC::Exception::Context->new->will_store_all;
our $this_app = $main::this_app;

# Return the fqdn of the node
sub get_fqdn 
{
    my $cfg = shift;
    my $h = $cfg->getElement (HOSTNAME)->getValue;
    my $d = $cfg->getElement (DOMAINNAME)->getValue;
    return "$h.$d";    
}

# return the anaconda version instance as specified in the kickstart (if at all)
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

# Returns the absolute path where the PXE file must be written.
sub filepath
{
    my $cfg = shift;

    my $fqdn = get_fqdn($cfg);
    my $dir = $this_app->option (NBPDIR);
    $this_app->debug(3, "NBP directory = $dir");
    return "$dir/$fqdn.cfg";
}

# Returns the absolute path of the PXE file to link to
sub link_filepath
{
    my ($cfg, $cmd) = @_;

    my $dir = $this_app->option (NBPDIR);

    my $cfgpath = PXEROOT . "/" . $cmd;
    if ($cfg->elementExists ($cfgpath)) {
        my $linkname = $cfg->getElement ($cfgpath)->getValue;
        return "$dir/$linkname";
    } elsif ($cmd eq RESCUE) {
        # Backwards compatibility: use the option set on the command line
        # if the profile does not define a rescue image
        my $path = $this_app->option (RESCUEBOOT);
        unless ($path =~ m{^([-.\w]+)$}) {
            $this_app->error ("Unexpected RESCUE configuration file");
        }
        return "$dir/$1";
    } else {
        my $fqdn = get_fqdn($cfg);
        $this_app->debug(3, "No $cmd defined for $fqdn");
    }
    return undef;
}


# Configure the ksdevice with static IP 
# (EL7+ only)
sub pxe_ks_static_network
{
    my ($config, $dev) = @_;

    my $fqdn = get_fqdn($config);
    
    my $bootdev = $dev;

    my $net = $config->getElement("/system/network/interfaces/$dev")->getTree;

    # check for bridge: if $dev is a bridge interface, 
    # continue with network settings on the bridge device
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
            return;
    }
    
    # can't set MTU with static ip via PXE

    my $gw;
    if ($net->{gateway}) {
        $gw = $net->{gateway};
    } elsif ($config->elementExists ("/system/network/default_gateway")) {
        $gw = $config->getElement ("/system/network/default_gateway")->getValue;
    } else {
        # This is a recipe for disaster
        # No best guess here
        $this_app->error ("No gateway defined for dev $dev and ",
                          " using static network description.");
        return;                
    };

    return "$net->{ip}::$gw:$net->{netmask}:$fqdn:$bootdev:none";
}


# create the network bonding parameters (if any)
sub pxe_network_bonding {
    my ($config, $tree, $dev) = @_;

    my $dev_exists = $config->elementExists("/system/network/interfaces/$dev");
    my $dev_invalid = $dev =~ m!(?:[0-9a-f]{2}(?::[0-9a-f]{2}){5})|bootif|link!i;
    # should not be disabled, generate detailed logging instead of immediately returning
    my $bonding_disabled = exists($tree->{bonding}) && (! $tree->{bonding});

    my $logerror = "error";
    my $bonding_disabled_msg = "";
    if ($bonding_disabled) {
        $bonding_disabled_msg = "Bonding config generation explicitly disabled";
        $logerror = "verbose";
        $this_app->$logerror($bonding_disabled_msg);
    }
    
    if (! $dev_exists) {
        if ($dev_invalid) {
            $this_app->$logerror("Invalid ksdevice $dev for bonding network configuration. $bonding_disabled_msg");
            return;
        } else {
            $this_app->$logerror("ksdevice $dev for bonding network configuration has matching no interface. $bonding_disabled_msg");
            return;
        }
    };
    
    my $net = $config->getElement("/system/network/interfaces/$dev")->getTree;

    # check for bonding 
    # if bonding not defined, assume it's allowed
    my $bonddev = $net->{master};

    # check the existence to deal with older profiles
    if ($bonding_disabled) {
        # lets hope you know what you are doing
        $this_app->warn ("$bonding_disabled_msg for dev $dev, with master $bonddev set.") if ($bonddev);
        return;
   } elsif ($bonddev) {
        # this is the dhcp code logic; adding extra error here. 
        if (!($net->{bootproto} && $net->{bootproto} eq "none")) {
            $this_app->error("Pretending this a bonded setup with bonddev $bonddev (and ksdevice $dev).",
                             "But bootproto=none is missing, so ncm-network will not treat it as one.");
        }
        $this_app->debug (5, "Ksdevice $dev is a bonding slave, node will boot from bonding device $bonddev");

        # bond network config
        $net = $config->getElement("/system/network/interfaces/$bonddev")->getTree;

        # gather the slaves, the ksdevice is put first 
        my @slaves;
        push(@slaves, $dev);
        my $intfs = $config->getElement("/system/network/interfaces")->getTree;
        for my $intf (sort keys %$intfs) {
            push (@slaves, $intf) if ($intfs->{$intf}->{master} && 
                                      $intfs->{$intf}->{master} eq $bonddev &&
                                      !(grep { $_ eq $intf } @slaves));
        };

        my $bondtxt = "bond=$bonddev:". join(',', @slaves);
        # gather the options
        if ($net->{bonding_opts}) {
            my @opts;
            while (my ($k, $v) = each(%{$net->{bonding_opts}})) {
                push(@opts, "$k=$v");
            }
            $bondtxt .= ":". join(',', @opts);
        }
        
        return ($bonddev, $bondtxt);
        
    }
    
}


# create a list with all append options for kickstart installations
sub pxe_ks_append 
{
    my $cfg = shift;

    my $t = $cfg->getElement (PXEROOT)->getTree;
    
    my $kst = {}; # empty hashref in case no kickstart is defined
    $kst = $cfg->getElement (KS)->getTree if $cfg->elementExists(KS);

    my $version = get_anaconda_version($kst);

    my $keyprefix = "";
    my $ksdevicename = "ksdevice";  
    if($version >= ANACONDA_VERSION_EL_7_0) {
        $keyprefix="inst.";

        if($t->{ksdevice} =~ m/^(bootif|link)$/ &&
            ! $cfg->elementExists("/system/network/interfaces/$t->{ksdevice}")) {
            $this_app->warn("Using deprecated legacy behaviour. Please look into the configuration.");
        } else {
            $ksdevicename = "bootdev";  
        }
    }  

    my $ksloc = $t->{kslocation};
    my $server = hostname();
    $ksloc =~ s{LOCALHOST}{$server};

    my @append;
    push(@append,
         "ramdisk=32768",
         "initrd=$t->{initrd}",
         "${keyprefix}ks=$ksloc",
         );         

    my $ksdev = $t->{ksdevice};
    if ($version >= ANACONDA_VERSION_EL_6_0) {
        # bond support in pxelinunx config 
        # (i.e using what device will the ks file be retrieved).
        my ($bonddev, $bondingtxt) = pxe_network_bonding($cfg, $kst, $ksdev);
        if ($bonddev) {
            $ksdev = $bonddev;
            push (@append, $bondingtxt);
        }
    }

    push(@append, "$ksdevicename=$ksdev");

    if ($t->{updates}) {
        push(@append,"${keyprefix}updates=$t->{updates}");
    };

    if ($kst->{logging} && $kst->{logging}->{host}) {
        push(@append, "${keyprefix}syslog=$kst->{logging}->{host}:$kst->{logging}->{port}"); 
        push(@append, "${keyprefix}loglevel=$kst->{logging}->{level}") if $kst->{logging}->{level};
    }
    
    if ($version >= ANACONDA_VERSION_EL_7_0) {
        if ($kst->{enable_sshd}) {
            push(@append, "${keyprefix}sshd");
        };
        
        if ($kst->{cmdline}) {
            push(@append, "${keyprefix}cmdline");
        };
        
        if ($t->{setifnames}) {
            # set all interfaces names to the configured macaddress
            my $nics = $cfg->getElement ("/hardware/cards/nic")->getTree;
            foreach my $nic (keys %$nics) {
                push (@append, "ifname=$nic:".$nics->{$nic}->{hwaddr}) if ($nics->{$nic}->{hwaddr});
            }
        }

        if($kst->{bootproto} eq 'static') {
            if ($ksdev =~ m/^((?:(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2})|bootif|link)$/i) {
                $this_app->error("Invalid ksdevice $ksdev for static ks configuration.");
            } else {
                my $static = pxe_ks_static_network($cfg, $ksdev);            
                push(@append,"ip=$static") if ($static);
            }
        } elsif ($kst->{bootproto} =~ m/^(dhcp6?|auto6|ibft)$/) {
            push(@append,"ip=$kst->{bootproto}");
        }
        
        my $nms = $cfg->getElement("/system/network/nameserver")->getTree;
        foreach my $ns (@$nms) {
            push(@append,"nameserver=$ns");
        }
    }
        
    push(@append, $t->{append}) if $t->{append};

    return @append;    
}

# create a list with all append options
sub pxe_append 
{
    my $cfg = shift;

    if ($cfg->elementExists(KS)) {
        return pxe_ks_append($cfg);
    } else {
        $this_app->error("Unclear how to create the append options. Not using any options.");
        return;
    }
}

# Prints the PXE configuration file.
sub pxeprint
{
    my $cfg = shift;
    my $t = $cfg->getElement (PXEROOT)->getTree;
    my $fh = CAF::FileWriter->open (filepath ($cfg),
				    log => $this_app, mode => 0644);

    my $appendtxt = '';
    my @appendoptions = pxe_append($cfg);
    $appendtxt = join(" ", "append", @appendoptions) if @appendoptions;

    $fh->print (<<EOF
# File generated by pxelinux AII plug-in.
# Do not edit.
default $t->{label}
    label $t->{label}
    kernel $t->{kernel}
    $appendtxt
EOF
           );
    # TODO is ksdevice still mandatory? if not, fix schema (code is already ok)
    # ksdecvice=bootif is an anaconda-ism, but can serve general purpose
    $fh->print ("    ipappend 2\n") if ($t->{ksdevice} && $t->{ksdevice} eq 'bootif');
    $fh->close();
}

# Prints an IP address in hexadecimal.
sub hexip
{
    my $ip = shift || "";

    return sprintf ("%02X%02X%02X%02X", $1, $2, $3, $4) if ($ip =~ m/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);
}

# Creates a symbolic link for PXE. This means creating a symlink named
# after the node's IP in hexadecimal to a PXE file.
sub pxelink
{
    my ($cfg, $cmd) = @_;

    my $t = $cfg->getElement (ETH)->getTree;
    my $path;
    if (!$cmd) {
        $path = $this_app->option (LOCALBOOT);
        $this_app->debug (5, "Configuring on $path");
    } elsif ($cmd eq BOOT) {
        $path = $this_app->option (LOCALBOOT);
        unless ($path =~ m{^([-.\w]+)$}) {
            $this_app->error ("Unexpected BOOT configuration file");
            return -1;
        }
        $path = $1;
        $this_app->debug (5, "Local booting from $path");
    } elsif ($cmd eq RESCUE || $cmd eq LIVECD || $cmd eq FIRMWARE) {
        $path = link_filepath($cfg, $cmd);
        if (! -f $path) {
            my $fqdn = get_fqdn($cfg);
            $this_app->error("Missing $cmd config file for $fqdn: $path");
            return -1;
        }
        $this_app->debug (5, "Using $cmd from: $path");
    } elsif ($cmd eq INSTALL) {
        $path = filepath ($cfg);
        $this_app->debug (5, "Installing on $path");
    } else {
        $this_app->debug (5, "Unknown command");
        return -1;
    }
    # Set the same settings for every network interface that has a
    # defined IP address.
    foreach my $st (values (%$t)) {
        next unless $st->{ip};
        my $dir = $this_app->option (NBPDIR);
        my $lnname = "$dir/".hexip ($st->{ip});
        if ($cmd || ! -l $lnname) {
            if ($NoAction) {
                $this_app->info ("Would symlink $path to $lnname");
            } else {
                unlink ($lnname);
                # This must be stripped to work with chroot'edg
                # environments.
                $path =~ s{$dir/?}{};
                symlink ($path, $lnname);
            }
        }
    }
    return 0;
}

# Sets the node's status to install.
sub Install
{
    my ($self, $cfg) = @_;

    unless (pxelink ($cfg, INSTALL)==0) {
        my $fqdn = get_fqdn($cfg);
        $self->error ("Failed to change the status of $fqdn to install");
        return 0;
    }
    ksuserhooks ($cfg, INSTALL_HOOK_PATH) unless $NoAction;
    return 1;
}

# Sets the node's status to firmware
sub Firmware
{
    my ($self, $cfg) = @_;

    unless (pxelink ($cfg, FIRMWARE)==0) {
        my $fqdn = get_fqdn($cfg);
        $self->error ("Failed to change the status of $fqdn to firmware");
        return 0;
    }
    ksuserhooks ($cfg, FIRMWARE_HOOK_PATH) unless $NoAction;
    return 1;
}

# Sets the node's status to livecd
sub Livecd
{
    my ($self, $cfg) = @_;

    unless (pxelink ($cfg, LIVECD)==0) {
        my $fqdn = get_fqdn($cfg);
        $self->error("Failed to change the status of $fqdn to livecd");
        return 0;
    }
    ksuserhooks ($cfg, LIVECD_HOOK_PATH) unless $NoAction;
    return 1;
}

# Sets the node's status to rescue.
sub Rescue
{
    my ($self, $cfg) = @_;

    unless (pxelink ($cfg, RESCUE)==0) {
        my $fqdn = get_fqdn($cfg);
        $self->error ("Failed to change the status of $fqdn to rescue");
        return 0;
    }
    ksuserhooks ($cfg, RESCUE_HOOK_PATH) unless $NoAction;
    return 1;
}

# Prints the status of the node.
sub Status
{
    my ($self, $cfg) = @_;

    my $t = $cfg->getElement (ETH)->getTree;
    my $dir = $this_app->option (NBPDIR);
    my $fqdn = get_fqdn($cfg);
    my $boot = $this_app->option (LOCALBOOT);
    my $rescue = link_filepath($cfg, RESCUE);
    my $firmware = link_filepath($cfg, FIRMWARE);
    my $livecd = link_filepath($cfg, LIVECD);
    foreach my $s (values (%$t)) {
        next unless $s->{ip};
        my $ln = hexip ($s->{ip});
        my $since = "unknown";
        my $st;
        if (-l "$dir/$ln") {
            $since = ctime(lstat("$dir/$ln")->ctime());
            my $name = readlink ("$dir/$ln");
            my $name_path = "$dir/$name";
            if (! -e $name_path) {
                $st = "broken";
            } elsif ($name =~ m{^(?:.*/)?$fqdn\.cfg$}) {
                $st = "install";
            } elsif ($name =~ m{^$boot$}) {
                $st = "boot";
            } elsif ($firmware && ($name_path =~ m{$firmware})) {
                $st = "firmware";
            } elsif ($livecd && ($name_path =~ m{$livecd})) {
                $st = "livecd";
            } elsif ($rescue && ($name_path =~ m{$rescue})) {
                $st = "rescue";
            } else {
                $st = "unknown";
            }
        } else {
            $st = "undefined";
        }
        $self->info(ref($self), " status for $fqdn: $s->{ip} $st ",
                "since: $since");
    }
    return 1;
}

# Sets the node's status to boot from local boot.
sub Boot
{
    my ($self, $cfg) = @_;
    pxelink ($cfg, BOOT);
    ksuserhooks ($cfg, BOOT_HOOK_PATH) unless $NoAction;
    return 1;
}

# Creates the PXE configuration file.
sub Configure
{
    my ($self, $cfg) = @_;

    pxeprint ($cfg);
    pxelink ($cfg);

    return 1;
}

# Removes PXE files and symlinks for the node. To be called by --remove.
sub Unconfigure
{
    my ($self, $cfg) = @_;

    if ($NoAction) {
        $self->info ("Would remove " . ref ($self));
        return 1;
    }

    my $t = $cfg->getElement (ETH)->getTree;
    my $path = filepath ($cfg);
    my $dir = $this_app->option (NBPDIR);
    # Set the same settings for every network interface.
    unlink ($path);
    unlink ("$dir/" . hexip ($_->{ip})) foreach values (%$t);
    ksuserhooks ($cfg, REMOVE_HOOK_PATH);
    return 1;
}
