#${PMpre} NCM::Component::pxelinux${PMpost}

use Sys::Hostname;
use CAF::FileWriter;
use CAF::Object qw(SUCCESS CHANGED);
use NCM::Component::ks qw (ksuserhooks);
use File::stat;
use File::Basename qw(dirname);
use Time::localtime;
use Readonly;

use parent qw (NCM::Component CAF::Path);

use constant PXEROOT => "/system/aii/nbp/pxelinux";
use constant HOSTNAME => "/system/network/hostname";
use constant DOMAINNAME => "/system/network/domainname";
use constant INTERFACES => "/system/network/interfaces";

# Kickstart constants (trying to use same name as in ks.pm from aii-ks)
use constant KS => "/system/aii/osinstall/ks";

# Lowest supported version is EL 5.0
use constant ANACONDA_VERSION_EL_5_0 => version->new("11.1");
use constant ANACONDA_VERSION_EL_6_0 => version->new("13.21");
use constant ANACONDA_VERSION_EL_7_0 => version->new("19.31");
use constant ANACONDA_VERSION_LOWEST => ANACONDA_VERSION_EL_5_0;

# Import PXE-related constants shared with other modules
use NCM::Component::PXELINUX::constants qw(:all);

# Support PXE variants and their parameters (currently PXELINUX and Grub2)
# 'name' is a descriptive name for information/debugging messages
# To add a new variant, define its name in PXELINUX::constants module, create a
# new xxx_VARIANT_PARAMS with the same structure as the existing one and add it
# in @VARIANT_PARAMS list. Then update the code where appropriate.
Readonly my %GRUB2_VARIANT_PARAMS => (name => 'Grub2',
                                      nbpdir_opt => NBPDIR_GRUB2,
                                      kernel_root_path => GRUB2_EFI_KERNEL_ROOT,
                                      format_method => '_write_grub2_config');
Readonly my %PXELINUX_VARIANT_PARAMS => (name => 'PXELINUX',
                                         nbpdir_opt => NBPDIR_PXELINUX,
                                         kernel_root_path => '',
                                         format_method => '_write_pxelinux_config');
# Element in @VARIANT_PARAMS must be in the same order as enum PXE_VARIANT_xxx
Readonly my @VARIANT_PARAMS => (\%PXELINUX_VARIANT_PARAMS, \%GRUB2_VARIANT_PARAMS);

our $EC = LC::Exception::Context->new->will_store_all;
our $this_app = $main::this_app;


# Return the value of a variant attribute.
# Attribute can be any valid key in one of the xxx_VARIANT_PARAMS
sub _variant_attribute
{
    my ($self, $attribute, $variant) = @_;
    return $VARIANT_PARAMS[$variant]->{$attribute};
}

# Return a configuration option value for a given variant.
# First argument is a variant attribute that will be interpreted
# as a configuration option.
sub _variant_option
{
    my ($self, $attribute, $variant) = @_;
    return $this_app->option ($self->_variant_attribute($attribute, $variant));
}

# Test if a variant is enabled
# A variant is enabled if the configuration option defined in its 'nbpdir' 
# attribute is defined and is not 'none'
sub _variant_enabled
{
    my ($self, $variant) = @_;
    my $nbpdir = $self->_variant_attribute('nbpdir_opt', $variant);
    $self->debug(2, "Using option '$nbpdir' to check if variant ", $self->_variant_attribute('name',$variant), " is enabled");
    my $enabled = $this_app->option_exists($nbpdir) &&
                  ($this_app->option($nbpdir) ne NBPDIR_VARIANT_DISABLED);
    return $enabled;
}


# Return the fqdn of the node
sub _get_fqdn
{
    my ($self, $cfg) = @_;
    my $h = $cfg->getElement (HOSTNAME)->getValue;
    my $d = $cfg->getElement (DOMAINNAME)->getValue;
    return "$h.$d";
}

# return the anaconda version instance as specified in the kickstart (if at all)
sub _get_anaconda_version
{
    my ($self, $kst) = @_;
    my $version = ANACONDA_VERSION_LOWEST;
    if ($kst->{version}) {
        $version = version->new($kst->{version});
        if ($version < ANACONDA_VERSION_LOWEST) {
            # TODO is this ok, or should we stop?
            $self->error("Version $version < lowest supported ".ANACONDA_VERSION_LOWEST.", continuing with lowest");
            $version = ANACONDA_VERSION_LOWEST;
        }
    };
    return $version;
}

# Retuns the IP-based PXE file name, based on the PXE variant
sub _hexip_filename
{
    my ($self, $ip, $variant) = @_;

    my $hexip_str = '';
    if ( $ip =~ m/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ ) {
        $hexip_str = sprintf ("%02X%02X%02X%02X", $1, $2, $3, $4);
        if ( $variant eq PXE_VARIANT_GRUB2 ) {
            $hexip_str = "grub.cfg-$hexip_str";
        } elsif ( $variant ne PXE_VARIANT_PXELINUX ) {
            $self->error("Internal error: invalid PXE variant ($variant)");
        }
    } else {
        $self->error("Invalid IPv4 address ($ip)");
    }

    return $hexip_str;
}

# Returns the absolute path of the PXE config file for the current host, based on the PXE variant
sub _file_path
{
    my ($self, $cfg, $variant) = @_;

    my $fqdn = $self->_get_fqdn($cfg);
    my $dir = $self->_variant_option('nbpdir_opt', $variant);
    $self->debug(2, "NBP directory (PXE variant=", $self->_variant_attribute('name',$variant), ") = $dir");
    return "$dir/$fqdn.cfg";
}

# Returns the absolute path of the PXE file to link to for actions other than
# CONFIGURE, BOOT and INSTALL, based on the PXE variant
sub _link_path
{
    my ($self, $cfg, $cmd, $variant) = @_;

    my $dir = $self->_variant_option('nbpdir_opt', $variant);
    my $pxe_config = $cfg->getElement (PXEROOT)->getTree();

    unless ( $cmd ) {
        $self->error("Internal error: link_path() called with an undefined action");
        return;
    };

    if ( $pxe_config->{$cmd} ) {
        return "$dir/$pxe_config->{$cmd}";
    } elsif (($cmd eq RESCUE) && $this_app->option_exists(RESCUEBOOT) ) {
        # Backwards compatibility for rescue image only: use the option
        # spsecified on the command line (if any) if none is defined in the profile
        my $path = $this_app->option (RESCUEBOOT);
        unless ($path =~ m{^([-.\w]+)$}) {
            $self->error ("Unexpected RESCUE configuration file");
        }
        return "$dir/$1";
    } else {
        $self->debug(1, "No configuration defined for action $cmd ");
    }

    return;
}


# Configure the ksdevice with a static IP
# (EL7+ only)
sub _pxe_ks_static_network
{
    my ($self, $config, $dev) = @_;

    my $fqdn = $self->_get_fqdn($config);

    my $bootdev = $dev;

    my $net = $config->getElement("/system/network/interfaces/$dev")->getTree;

    # check for bridge: if $dev is a bridge interface,
    # continue with network settings on the bridge device
    if ($net->{bridge}) {
        my $brdev = $net->{bridge};
        $self->debug (2, "Device $dev is a bridge interface for bridge $brdev.");
        # continue with network settings for the bridge device
        $net = $config->getElement("/system/network/interfaces/$brdev")->getTree;
        # warning: $dev is changed here to the bridge device to create correct log
        # messages in remainder of this method. as there is not bridge device
        # in anaconda phase, the new value of $dev is not an actual network device!
        $dev = $brdev;
    }

    unless ($net->{ip}) {
            $self->error ("Static boot protocol specified ",
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
        $self->error ("No gateway defined for dev $dev and ",
                          " using static network description.");
        return;
    };

    return "$net->{ip}::$gw:$net->{netmask}:$fqdn:$bootdev:none";
}


# create the network bonding parameters (if any)
sub _pxe_network_bonding {
    my ($self, $config, $tree, $dev) = @_;

    my $dev_exists = $config->elementExists("/system/network/interfaces/$dev");
    my $dev_invalid = $dev =~ m!(?:[0-9a-f]{2}(?::[0-9a-f]{2}){5})|bootif|link!i;
    # should not be disabled, generate detailed logging instead of immediately returning
    my $bonding_disabled = exists($tree->{bonding}) && (! $tree->{bonding});

    my $logerror = "error";
    my $bonding_cfg_msg = "";
    if (! exists($tree->{bonding})) {
        $bonding_cfg_msg = "Bonding config generation not defined, continuing best-effort";
        $logerror = "verbose";
    } elsif ($bonding_disabled) {
        $bonding_cfg_msg = "Bonding config generation explicitly disabled";
        $logerror = "verbose";
        $self->$logerror($bonding_cfg_msg);
    }

    if (! $dev_exists) {
        if ($dev_invalid) {
            $self->$logerror("Invalid ksdevice $dev for bonding network configuration. $bonding_cfg_msg");
        } else {
            $self->$logerror("ksdevice $dev for bonding network configuration has no matching interface. $bonding_cfg_msg");
        }
        return;
    }

    my $net = $config->getElement("/system/network/interfaces/$dev")->getTree;

    # check for bonding
    # if bonding not defined, assume it's allowed
    my $bonddev = $net->{master};

    # check the existence to deal with older profiles
    if ($bonding_disabled) {
        # lets hope you know what you are doing
        $self->warn ("$bonding_cfg_msg for dev $dev, with master $bonddev set.") if ($bonddev);
        return;
   } elsif ($bonddev) {
        # this is the dhcp code logic; adding extra error here.
        if (!($net->{bootproto} && $net->{bootproto} eq "none")) {
            $self->error("Pretending this a bonded setup with bonddev $bonddev (and ksdevice $dev).",
                             "But bootproto=none is missing, so ncm-network will not treat it as one.");
        }
        $self->debug (5, "Ksdevice $dev is a bonding slave, node will boot from bonding device $bonddev");

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


# create a list with all kernel parameters for the kickstart installation
sub _kernel_params_ks
{
    my ($self, $cfg, $variant) = @_;

    my $pxe_config = $cfg->getElement (PXEROOT)->getTree;

    my $kst = {}; # empty hashref in case no kickstart is defined
    $kst = $cfg->getElement (KS)->getTree if $cfg->elementExists(KS);

    my $version = $self->_get_anaconda_version($kst);

    my $keyprefix = "";
    my $ksdevicename = "ksdevice";
    if($version >= ANACONDA_VERSION_EL_7_0) {
        $keyprefix="inst.";

        if($pxe_config->{ksdevice} =~ m/^(bootif|link)$/ &&
            ! $cfg->elementExists("/system/network/interfaces/$pxe_config->{ksdevice}")) {
            $self->warn("Using deprecated legacy behaviour. Please look into the configuration.");
        } else {
            $ksdevicename = "bootdev";
        }
    }

    my $ksloc = $pxe_config->{kslocation};
    my $server = hostname();
    $ksloc =~ s{LOCALHOST}{$server};

    # With PXELINUX, initrd path is specified with a kernel parameter
    # Parameter order is not important but is kept as "ramdisk, initrd, ks" for compatibility
    # with previous AII versions for easier comparisons.
    my @kernel_params =  ("ramdisk=32768");
    push (@kernel_params, "initrd=$pxe_config->{initrd}") if ( $variant == PXE_VARIANT_PXELINUX );
    push (@kernel_params, "${keyprefix}ks=$ksloc");

    my $ksdev = $pxe_config->{ksdevice};
    if ($version >= ANACONDA_VERSION_EL_6_0) {
        # bond support in pxelinunx config
        # (i.e using what device will the ks file be retrieved).
        my ($bonddev, $bondingtxt) = $self->_pxe_network_bonding($cfg, $kst, $ksdev);
        if ($bonddev) {
            $ksdev = $bonddev;
            push (@kernel_params, $bondingtxt);
        }
    }

    push(@kernel_params, "$ksdevicename=$ksdev");

    if ($pxe_config->{updates}) {
        push(@kernel_params,"${keyprefix}updates=$pxe_config->{updates}");
    };

    if ($kst->{logging} && $kst->{logging}->{host}) {
        push(@kernel_params, "${keyprefix}syslog=$kst->{logging}->{host}:$kst->{logging}->{port}");
        push(@kernel_params, "${keyprefix}loglevel=$kst->{logging}->{level}") if $kst->{logging}->{level};
    }

    if ($version >= ANACONDA_VERSION_EL_7_0) {
        if ($kst->{enable_sshd}) {
            push(@kernel_params, "${keyprefix}sshd");
        };

        if ($kst->{cmdline}) {
            push(@kernel_params, "${keyprefix}cmdline");
        };

        if ($pxe_config->{setifnames}) {
            # set all interfaces names to the configured macaddress
            my $nics = $cfg->getElement ("/hardware/cards/nic")->getTree;
            foreach my $nic (keys %$nics) {
                push (@kernel_params, "ifname=$nic:".$nics->{$nic}->{hwaddr}) if ($nics->{$nic}->{hwaddr});
            }
        }

        if($kst->{bootproto} eq 'static') {
            if ($ksdev =~ m/^((?:(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2})|bootif|link)$/i) {
                $self->error("Invalid ksdevice $ksdev for static ks configuration.");
            } else {
                my $static = $self->_pxe_ks_static_network($cfg, $ksdev);
                push(@kernel_params,"ip=$static") if ($static);
            }
        } elsif ($kst->{bootproto} =~ m/^(dhcp6?|auto6|ibft)$/) {
            push(@kernel_params,"ip=$kst->{bootproto}");
        }

        my $nms = $cfg->getElement("/system/network/nameserver")->getTree;
        foreach my $ns (@$nms) {
            push(@kernel_params,"nameserver=$ns");
        }
    }

    my $custom_append = $pxe_config->{append};
    if ($custom_append) {
	    $custom_append =~ s/LOCALHOST/$server/g;
	    push @kernel_params, $custom_append;
    }
    
    return @kernel_params;    
}

# create a list with all required kernel parameters, based on the configuration
sub _kernel_params
{
    my ($self, $cfg, $variant) = @_;

    if ($cfg->elementExists(KS)) {
        return $self->_kernel_params_ks($cfg, $variant);
    } else {
        $self->error("No Kickstart-related parameters in configuration: no kernel parameters added.");
        return;
    }
}

# Write the PXELINUX configuration file.
sub _write_pxelinux_config
{
    my ($self, $cfg) = @_;
    my $pxe_config = $cfg->getElement (PXEROOT)->getTree;
    my $fh = CAF::FileWriter->open ($self->_file_path ($cfg, PXE_VARIANT_PXELINUX),
                    log => $self, mode => 0644);

    my $appendtxt = '';
    my @appendoptions = $self->_kernel_params($cfg, PXE_VARIANT_PXELINUX);
    $appendtxt = join(" ", "append", @appendoptions) if @appendoptions;

    my $entry_label = "Install $pxe_config->{label}";
    print $fh <<EOF;
# File generated by pxelinux AII plug-in.
# Do not edit.
default $entry_label

label $entry_label
    kernel $pxe_config->{kernel}
    $appendtxt
EOF

    # TODO is ksdevice still mandatory? if not, fix schema (code is already ok)
    # ksdecvice=bootif is an anaconda-ism, but can serve general purpose
    $fh->print ("    ipappend 2\n") if ($pxe_config->{ksdevice} && $pxe_config->{ksdevice} eq 'bootif');
    $fh->close();
}


# Write the Grub2 configuration file.
# Return 1 if the file was written successfully, 0 otherwise.
# TODO: handle append options?
sub _write_grub2_config
{
    my ($self, $cfg) = @_;
    my $pxe_config = $cfg->getElement (PXEROOT)->getTree;

    my $linux_cmd = $this_app->option(GRUB2_EFI_LINUX_CMD);
    unless ( $linux_cmd ) {
        $self->error("AII option ".GRUB2_EFI_LINUX_CMD." undefined");
        return 0;
    };
    my $initrd_cmd = $this_app->option(GRUB2_EFI_INITRD_CMD);
    unless ( $initrd_cmd ) {
        $self->error("AII option ".GRUB2_EFI_INITRD_CMD." undefined");
        return 0;
    };
    my $kernel_root = $this_app->option(GRUB2_EFI_KERNEL_ROOT);
    $kernel_root = '' unless defined($kernel_root);
    my $kernel_path = "$kernel_root/$pxe_config->{kernel}";
    my $initrd_path = "$kernel_root/$pxe_config->{initrd}";

    my @kernel_params = $self->_kernel_params($cfg, PXE_VARIANT_PXELINUX);
    @kernel_params = () unless @kernel_params;
    my $kernel_params_text = join(' ', @kernel_params);
    $kernel_params_text = ' ' . $kernel_params_text if $kernel_params_text;

    my $fh = CAF::FileWriter->open ($self->_file_path ($cfg, PXE_VARIANT_GRUB2),
                                    log => $self, mode => 0644);
    print $fh <<EOF;
# File generated by pxelinux AII plug-in.
# Do not edit.
set default=0
set timeout=2
menuentry "Install $pxe_config->{label}" {
    set root=(pxe)
    $linux_cmd $kernel_path$kernel_params_text
    $initrd_cmd $initrd_path
    }
}
EOF

    # TODO: add specific processing of ksdevice=bootif as for PXELINUX?
    $fh->close();

    return 1;
}


# Creates a symbolic link for PXE. This means creating a symlink named
# after the node's IP in hexadecimal to a PXE file.
# Returns 1 on succes, 0 otherwise.
sub _pxelink
{
    my ($self, $cfg, $cmd, $variant) = @_;

    my $interfaces = $cfg->getElement (INTERFACES)->getTree;
    my $path;
    if (!$cmd) {
        $path = $this_app->option (LOCALBOOT);
        $self->debug (2, "Configuring on $path");
    } elsif ($cmd eq BOOT) {
        $path = $this_app->option (LOCALBOOT);
        unless ($path =~ m{^([-.\w]+)$}) {
            $self->error ("Unexpected BOOT configuration file");
            return 0;
        }
        $path = $1;
        $self->debug (5, "Local booting from $path");
    } elsif ($cmd eq RESCUE || $cmd eq LIVECD || $cmd eq FIRMWARE) {
        $path = $self->_link_path($cfg, $cmd, $variant);
        if (! $self->file_exists($path) ) {
            my $fqdn = $self->_get_fqdn($cfg);
            $self->error("Missing $cmd config file for $fqdn: $path");
            return 0;
        }
        $self->debug (2, "Using $cmd from: $path");
    } elsif ($cmd eq INSTALL) {
        $path = $self->_file_path ($cfg, $variant);
        $self->debug (2, "Installing on $path");
    } else {
        $self->debug (2, "Unknown command");
        return 0;
    }
    # Set the same settings for every network interface that has a
    # defined IP address.
    foreach my $st (values (%$interfaces)) {
        next unless $st->{ip};
        my $dir = $self->_variant_option('nbpdir_opt', $variant);
        my $lnname = "$dir/".$self->_hexip_filename ($st->{ip}, $variant);
        if ($cmd || ! $self->is_symlink($lnname) ) {
            $self->debug(2, "Removing $lnname if it exists");
            my $unlink_status = $self->cleanup ($lnname);
            if ( ! defined($unlink_status) ) {
                $self->error("Failed to delete $lnname (error=$self->{fail})");
            } elsif ( $unlink_status == SUCCESS ) {
                $self->debug(1, "PXE link $lnname not found");
            } else {
                $self->debug(1, "PXE link $lnname successfully removed");
            };
            # This must be stripped to work with chroot'ed environments.
            $path =~ s{$dir/?}{};
            $self->debug(2, "Creating symlink $lnname (target=$path)");
            $self->symlink ($path, $lnname);
        }
    }

    return 1;
}


# Wrapper function to call ksuserhooks() from aii-ks module.
# The only role of this function is to ensure that ksuserhooks()
# is always called the same way (in particular for NoAction
# handling). Be sure to use it!
# TODO: remove this function and use ksuserhooks directly when it has
# been made safe with NoAction
sub _exec_userhooks {
    my ($self, $cfg, $hook_path) = @_;

    if ( $CAF::Object::NoAction ) {
        $self->info("NoAction set: not running user hooks");
    } else {
        ksuserhooks ($cfg, $hook_path);
    };
}


# Prints the status of the node.
# Display information for both PXELINUX and Grub2 variant.

sub Status
{
    my ($self, $cfg) = @_;

    my $interfaces = $cfg->getElement (INTERFACES)->getTree;

    foreach my $variant_constant (@PXE_VARIANTS) {
        my $variant = __PACKAGE__->$variant_constant;
        my $dir = $self->_variant_option('nbpdir_opt', $variant);
        my $boot = $this_app->option (LOCALBOOT);
        my $fqdn = $self->_get_fqdn($cfg);
        my $rescue = $self->_link_path($cfg, RESCUE, $variant);
        my $firmware = $self->_link_path($cfg, FIRMWARE, $variant);
        my $livecd = $self->_link_path($cfg, LIVECD, $variant);
        foreach my $interface (sort(values(%$interfaces))) {
            next unless $interface->{ip};
            my $ln = $self->_hexip_filename ($interface->{ip}, $variant);
            my $since = "unknown";
            my $st;
            if ( $self->is_symlink("$dir/$ln") ) {
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
            $self->info(ref($self), "status for $fqdn: $interface->{ip} $st since: $since (PXE variant=",
                                    $self->_variant_attribute('name', $variant), ")");
        }
    }
    
    $self->_exec_userhooks ($cfg, STATUS_HOOK_PATH);
    
    return 1;
}

# Removes PXE files and symlinks for the node. To be called by --remove.
# This must be done for PXELINUX and Grub2 variants.
sub Unconfigure
{
    my ($self, $cfg) = @_;

    my $interfaces = $cfg->getElement (INTERFACES)->getTree;

    foreach my $variant_constant (@PXE_VARIANTS) {
        my $variant = __PACKAGE__->$variant_constant;
        my $pxe_config_file = $self->_file_path ($cfg, $variant);
        # Remove the PXEe config file for the current host
        $self->debug(1, "Removing PXE config file $pxe_config_file (PXE variant=",
                            $self->_variant_attribute('name', $variant), ")");
        my $unlink_status = $self->cleanup($pxe_config_file);
        if ( ! defined($unlink_status) ) {
            $self->error("Failed to delete $pxe_config_file (error=$self->{fail})");
        } elsif ( $unlink_status == SUCCESS ) {
            $self->debug(1, "PXE config file $pxe_config_file not found");
        } else {
            $self->debug(1, "PXE config file $pxe_config_file successfully removed");
        };
        # Remove the symlink for every interface with an IP address
        while (my ($interface, $params) = each %$interfaces) {
            if ( defined($params->{ip}) ) {
                my $pxe_symlink =  dirname($pxe_config_file) . "/" . $self->_hexip_filename ($params->{ip}, $variant);
                $self->debug(1, "Removing symlink $pxe_symlink for interface $interface (PXE variant=",
                                    $self->_variant_attribute('name', $variant), ")");
                my $unlink_status = $self->cleanup($pxe_symlink);
                if ( ! defined($unlink_status) ) {
                    $self->error("Failed to delete $pxe_symlink (error=$self->{fail})");
                } elsif ( $unlink_status == SUCCESS ) {
                    $self->debug(1, "PXE link $pxe_symlink not found");
                } else {
                    $self->debug(1, "PXE link $pxe_symlink successfully removed");
                };
            };
        };
        $self->_exec_userhooks ($cfg, REMOVE_HOOK_PATH);
    }

    return 1;        
}


no strict 'refs';
foreach my $operation (qw(configure boot rescue livecd firmware install)) {
    my $name = ucfirst($operation);
    my $cmd = uc($operation);

    *{$name} = sub {
        my ($self, $cfg) = @_;

        foreach my $variant_constant (@PXE_VARIANTS) {
            my $variant = __PACKAGE__->$variant_constant;
            if ( $self->_variant_enabled($variant) ) {
                $self->verbose("Executing action '$operation' for variant ", $self->_variant_attribute('name', $variant));
                my $method = $self->_variant_attribute('format_method', $variant);
                $self->$method($cfg) if ($operation eq 'configure');

                unless ( $self->_pxelink ($cfg, &$cmd(), $variant) ) {
                    my $fqdn = $self->_get_fqdn($cfg);
                    $self->error ("Failed to change the status of $fqdn to $operation");
                    return 0;
                }
            } else {
                $self->debug(1, "Variant ", $self->_variant_attribute('name',$variant), " disabled: action '$operation' not executed");
            }
        }
        $self->_exec_userhooks ($cfg, HOOK_PATH.$operation);
        return 1;
    };
};
use strict 'refs';

1;
