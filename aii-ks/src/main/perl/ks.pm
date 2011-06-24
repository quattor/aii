# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
# File: ks.pm
# Implementation of ncm-ks
# Author: Luis Fernando Muñoz Mejías
# Version: 1.1.33 : 27/02/11 12:30
#  ** Generated file : do not edit **
#
# Note: all methods in this component are called in a
# $self->$method ($config) way, unless explicitly stated.

#package NCM::Component::ks;
package NCM::Component::ks;

use strict;
use warnings;
use NCM::Component;
use EDG::WP4::CCM::Property;
use EDG::WP4::CCM::Element qw (unescape);
use NCM::Filesystem;
use NCM::Partition qw (partition_compare);
use NCM::BlockdevFactory qw (build);
use NCM::Check;
use FileHandle;
use LC::Exception qw (throw_error);
use Data::Dumper;
use NCM::Template;
use Exporter;
use CAF::FileWriter;
use Sys::Hostname;

our @ISA = qw (NCM::Component Exporter);
our $EC = LC::Exception::Context->new->will_store_all;

our $this_app = $main::this_app;
# Modules that may be interesting for hooks.
our @EXPORT_OK = qw (kspkglist kspkgurl ksuserhooks ksinstall_rpm);

# PAN paths for some of the information needed to generate the
# Kickstart.
use constant { KS		=> "/system/aii/osinstall/ks",
	       HOSTNAME		=> "/system/network/hostname",
	       DOMAINNAME	=> "/system/network/domainname",
	       FS		=> "/system/filesystems/",
	       PART		=> "/system/blockdevices/partitions",
	       REPO		=> "/software/repositories",
	       PRESCRIPT	=> "/system/aii/osinstall/ks/pre_install_script",
	       PREHOOK		=> "/system/aii/hooks/pre_install",
	       POSTREBOOTSCRIPT	=> "/system/aii/osinstall/ks/post_reboot_script",
	       POSTREBOOTHOOK	=> "/system/aii/hooks/post_reboot",
	       POSTSCRIPT	=> "/system/aii/osinstall/ks/post_install_script",
	       POSTHOOK		=> "/system/aii/hooks/post_install",
	       ANACONDAHOOK	=> "/system/aii/hooks/anaconda",
	       PREREBOOTHOOK	=> "/system/aii/hooks/pre_reboot",
	       PKG		=> "/software/packages/",
	       KERNELVERSION	=> "/system/kernel/version",
	       ACKURL		=> "/system/aii/osinstall/ks/ackurl",
	       ACKLIST          => "/system/aii/osinstall/ks/acklist",
	       CARDS		=> "/hardware/cards/nic",
	       SPMAPROXY	=> "/software/components/spma/proxy",
	       SPMA		=> "/software/components/spma",
	       ROOTMAIL		=> "/system/rootmail",
	       AII_PROFILE	=> "/system/aii/osinstall/ks/node_profile",
	       CCM_PROFILE	=> "/software/components/ccm/profile",
	       CCM_KEY		=> "/software/components/ccm/key_file",
	       CCM_CERT		=> "/software/components/ccm/cert_file",
	       CCM_CA		=> "/software/components/ccm/ca_file",
	       CCM_WORLDR	=> "/software/components/ccm/world_readable",
               CCM_DBFORMAT     => "/software/components/ccm/dbformat",
	       EMAIL_SUCCESS	=> "/system/aii/osinstall/ks/email_success",
	       NAMESERVER	=> "/system/network/nameserver/0",
	   };
my $localhost = hostname();

# Base package path for user hooks.
use constant   MODULEBASE	=> "";
use constant   USEMODULE	=> "use " . MODULEBASE;

# Configuration variable for the osinstall directory.
use constant   KSDIROPT		=> 'osinstalldir';

# Packages to be installed when setting up Quattor.
use constant QUATTOR_LIST	=> qw (perl-Compress-Zlib
				       perl-LC
				       perl-AppConfig-caf
				       perl-Proc-ProcessTable
				       perl-IO-String
				       perl-CAF
				       ccm
				       ncm-template
				       ncm-ncd
				       ncm-query
				       rpmt-py
				       spma
				       ncm-spma
				       cdp-listend
				       ncm-cdispd
				       );

# Packages containing kernels. kernel-xen is not listed here, as it
# depends on different versions of mkinitrd and e2fsprogs, and
# installing them may cause a dependency hell.
use constant KERNELLIST		=> qw (kernel kernel-smp);

# Opens the kickstart file and sets its handle as the default.
sub ksopen
{
    my ($self, $cfg) = @_;

    my $host = $cfg->getElement (HOSTNAME)->getValue;
    my $domain = $cfg->getElement (DOMAINNAME)->getValue;

    my $ksdir = $this_app->option (KSDIROPT);
    $self->debug(3,"Kickstart file directory = $ksdir");

    my $ks = CAF::FileWriter->open ("$ksdir/$host.$domain.ks",
				    mode => 0664, log => $this_app);
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

# Configures the network, allowing both DHCP and static boots.
sub ksnetwork
{
    my ($tree, $config) = @_;

    if ($tree->{bootproto} eq 'dhcp') {
	$this_app->debug (5, "Node configures its network via DHCP");
	print "network --bootproto=dhcp\n";
	return;
    }

    my $dev = $config->getElement("/system/aii/nbp/pxelinux/ksdevice")->getValue;
    my $fqdn = $config->getElement (HOSTNAME)->getValue . "." .
      $config->getElement (DOMAINNAME)->getValue;
    return unless $dev =~ m/eth\d+/;
    $this_app->debug (5, "Node will boot from $dev");
    my $net = $config->getElement("/system/network/interfaces/$dev")->getTree;
    unless (exists ($net->{ip})) {
	    $this_app->error ("Static boot protocol specified ",
			      "but no IP given to the interface");
	    return;
    }
    my $gw = '--gateway='; 
    if (exists($net->{gateway})) {
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

    my $ns = $config->getElement(NAMESERVER)->getValue;
    print <<EOF;
network --bootproto=static --ip=$net->{ip} --netmask=$net->{netmask} $gw --nameserver=$ns --device=$dev --hostname=$fqdn
EOF

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
	$this_app->debug (5, "Loading " . MODULEBASE . $tree->{module});
	eval (USEMODULE . $tree->{module});
	throw_error ("Couldn't load module $tree->{module}: $@")
	  if $@;
	my $hook = eval (MODULEBASE . $tree->{module} . "->new");
	throw_error ("Couldn't instantiate object of class $tree->{module}")
	  if $@;
	$this_app->debug (5, "Running $tree->{module}->$method");
	$hook->$method ($config, $nelpath);
    }
}


# Prints to the Kickstart all the non-partitioning directives.
sub kscommands
{
    my  $config = shift;

    my $tree = $config->getElement(KS)->getTree;

    my $installtype = $tree->{installtype};
    if ($installtype =~ /http/) {
        my ($proxyhost, $proxyport) = proxy($config);
        if ($proxyhost) {
            if ($proxyport) {
                $proxyhost .= ":$proxyport";
            }
            $installtype =~ s{(https?)://([^/]*)/}{$1://$proxyhost/};
        }
    }
    print <<EOF;
install
text
reboot
$installtype
timezone --utc $tree->{timezone}
rootpw --iscrypted $tree->{rootpw}
EOF

    print "bootloader  --location=$tree->{bootloader_location}";
    print " --driveorder=", join(',', @{$tree->{bootdisk_order}})
        if exists $tree->{bootdisk_order};
    print " --append=\"$tree->{bootloader_append}\""
        if exists $tree->{bootloader_append};
    print "\n";

    if (exists $tree->{xwindows}) {
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
	print "skipx\n" unless exists $tree->{xwindows};
    }

    print "key $tree->{installnumber}\n" if exists $tree->{installnumber};
    print "auth ";
    print "--$_ " foreach @{$tree->{auth}};
    print "\n";

    print "lang $tree->{lang}\n";
    print "langsupport ", join (" ", @{$tree->{langsupport}}), "\n"
        unless (@{$tree->{langsupport}}[0] eq "none");

    print "keyboard $tree->{keyboard}\n";
    print "mouse $tree->{mouse}\n" if exists $tree->{mouse};

    print "selinux --$tree->{selinux}\n" if exists $tree->{selinux};

    print "firewall --", $tree->{firewall}->{enabled}? "enabled":"disabled",
      " ";
    print "--trusted $_ " foreach @{$tree->{firewall}->{trusted}};
    print "--$_ " foreach @{$tree->{firewall}->{services}};
    print "--port $_ " foreach @{$tree->{firewall}->{ports}};
    print "\n";
    ksnetwork ($tree, $config);

    print "driverdisk --source=$_\n" foreach @{$tree->{driverdisk}};
    print "zerombr yes\n" if $tree->{clearmbr};

    if (exists ($tree->{ignoredisk}) &&
	scalar (@{$tree->{ignoredisk}})) {
	print "ignoredisk --drives=",
	    join (',', @{$tree->{ignoredisk}}), "\n";
    }

    my $pkgswitches = $tree->{package_switches} ?
      join(" ", @{$tree->{package_switches}}) : "--resolvedeps --ignoremissing";
	  $this_app->debug (3, "Setting %package switches to '${pkgswitches}'");
    print "%packages ${pkgswitches}\n",
      join ("\n", @{$tree->{packages}}), "\n";

}

# Writes the mountpoint definitions and LVM and MD settings
sub ksmountpoints
{
    my $config = shift;

    # Skip the remainder if "/system/filesystems" is undefined
    return unless ( $config->elementExists (FS) );

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
# placed.
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

    kscommands ($config);
}

# Takes care of the pre-install script, in which the 
sub pre_install_script
{
    my ($self, $config) = @_;

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

# Make sure messages show up on the serial console
exec >/dev/console 2>&1

# Hack for RHEL 6: force re-reading the partition table
rereadpt () {
    sync
    sleep 2
    hdparm -z \$1
}

# Align the start of a partition
align () {
    disk="\$1"
    path="\$2"
    n="\$3"
    align_sect="\$4"

    START=`fdisk -ul \$disk | awk "{if (\\\$1 == "\$path") print \\\$2 == "*" ? \\\$3: \\\$2}"`
    ALIGNED=\$(((\$START + \$align_sect - 1) / \$align_sect * \$align_sect))
    if [ \$START != \$ALIGNED ]; then
	echo "Aligning \$path: old start sector: \$START, new: \$ALIGNED"
	fdisk \$disk <<end_of_fdisk
x
b
\$n
\$ALIGNED
w
end_of_fdisk

	rereadpt \$disk
    fi
}

EOF

    # Hook handling should come here, to allow NIKHEF to override
    # partitioning.
    ksuserhooks ($config, PREHOOK);

    ksprint_filesystems ($config);
    # Is this needed if we are allowing for hooks?
    ksuserscript ($config, PRESCRIPT);

    print <<EOF;

# De-activate logical volumes. Needed on RHEL6, see:
# https://bugzilla.redhat.com/show_bug.cgi?id=652417
lvm vgchange -an

EOF
}

# Prints the code needed for removing and creating partitions, block
# devices and filesystems
sub ksprint_filesystems
{
    my $config = shift;

    # Skip the remainder if "/system/filesystems" is not defined
    return unless ( $config->elementExists (FS) );

    my $fss = $config->getElement (FS);
    my @filesystems = ();

    # Destroy what needs to be destroyed.
    my $clear = [];

    if ($config->elementExists ("/system/aii/osinstall/ks/clearpart")) {
	$clear = $config->getElement ("/system/aii/osinstall/ks/clearpart")->getTree;
    }
	
    foreach (@$clear) {
	my $disk = build ($config, "physical_devs/$_");
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
	push (@part, $pt);
    }
    # Partitions go first, as of bug #26137
    $_->create_pre_ks foreach (sort partition_compare @part);
    $_->align_ks foreach (sort partition_compare @part);
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

# Returns the list of packages specified on the profile with the given
# names.
sub kspkglist
{
    my ($config, @pkgnames) = @_;

    my @pkgs = ();
    foreach my $pn (@pkgnames) {
	my $path = PKG . NCM::Template::escape ($pn);
	next unless $config->elementExists ($path);
	my $vers = $config->getElement ($path)->getTree;
	while (my ($version, $vals) = each (%$vers)) {
	    my $v = unescape ($version);
	    my $archs = $vals->{arch};
            if ( exists ($vals->{repository}) ) {
                # Previous ncm-spma <2.0 schema
	        my $rep = $vals->{repository};
	        push (@pkgs, { pkg=>"$pn-$v.$_.rpm",
			       rep=>$rep
			     }) foreach @$archs;
            } else {
                # New ncm-spma v2.0 schema 
                while (my ($arch, $rep) = each (%$archs)) {
                   push(@pkgs, { pkg=>"$pn-$v.$arch.rpm", rep=>$rep});
                }
            }
	}
    }
    return @pkgs;
}

# Returns the URL to the package given as argument.
sub kspkgurl
{
    my ($config, $pkg) = @_;
    my $repos = $config->getElement (REPO)->getTree;
    $this_app->debug (5, "Generating package list for $pkg->{pkg}");
    foreach (@$repos) {
	return "$_->{protocols}->[0]->{url}/$pkg->{pkg}"
	  if $_->{name} eq $pkg->{rep};
    }
}

# Prints the statements needed to install a given set of RPMs
sub ksinstall_rpm
{
    my ($config, @pkgs) = @_;

    my @pkglist = kspkglist ($config, @pkgs);
    my $proxy_opts = "";

    my ($proxyhost, $proxyport) = proxy($config);
    if ($proxyhost) {
        $proxy_opts = "--httpproxy $proxyhost ";
        if ($proxyport) {
            $proxy_opts .= "--httpport $proxyport ";
        }
    }
    print "/bin/rpm -i --force $proxy_opts \"", kspkgurl ($config, $_), "\" || \\\n",
      " "x4, "fail \"Failed to install $_->{pkg}: \\\$?\"\n"
	foreach @pkglist;
}

sub proxy {
    my ($config) = @_;
    my ($proxyhost, $proxyport);
    if ($config->elementExists (SPMAPROXY)) {
	my $spma = $config->getElement (SPMA)->getTree;
	my $proxy_host = $spma->{proxyhost};
	my @proxies = split /,/,$proxy_host;
	if (scalar(@proxies) == 1) {
	    # there's only one proxy specified
            $proxyhost = $spma->{proxyhost};
	} elsif (scalar(@proxies) > 1) {
	    # optimize by picking the responding server as the proxy
	    my ($me) = grep { /\b$localhost\b/ } @proxies;
	    $me ||= $proxies[0];
            $proxyhost = $me;
	}
        if (exists $spma->{proxyport}) {
            $proxyport = $spma->{proxyport};
        }
    }
    return ($proxyhost, $proxyport);
}

# Prints the Bash code to install all the kernels specified in the
# profile and sets the default (the one on /system/kernel/version) as
# grub's default.
sub ksinstall_kernels
{
    my $config = shift;

    print <<EOF;

# The kernel must be upgraded now. See bugs #5007 and #28380.
EOF
	
    ksinstall_rpm ($config, KERNELLIST);

    # Set the default kernel
    my $kv = $config->getElement (KERNELVERSION)->getValue;
    print <<EOF;

# This will make us boot using the kernel specified in the profile,
# see bug #28380
default=\$(grep vmlinuz /boot/grub/grub.conf| \\
    nl -v-1|grep "$kv\[[:blank:]]"|head -n1| \\
    awk '{print \$1}')
if [ ! -z "\$default" ]
then
    sed -i "s/^\\(default\\)=.*/\\1=\$default/" /boot/grub/grub.conf
fi

# If the installer runs a different kernel version than it is being installed,
# then module loading (e.g. when ncm-network tries to configure a bonding
# interface) will not work during the build. Let's hope that the two kernels
# are at least ABI compatible...
_kernel_link_cleanup=
if [ `uname -r` != $kv ]; then
    if [ ! -d /lib/modules/`uname -r` ]; then
	ln -s /lib/modules/$kv /lib/modules/`uname -r`

	# Tell the post-install script to remove the link before reboot
	_kernel_link_cleanup=/lib/modules/`uname -r`
	export _kernel_link_cleanup
    fi
fi
EOF
}

# Prints the code for installing the drivers for the network
# interfaces.
sub ksinstall_drivers
{
    my $config = shift;

    my $cards = $config->getElement (CARDS)->getTree;

    my @pkgs = ();
    foreach my $card (values (%$cards)) {
	push (@pkgs, $card->{driverrpms})
	  if (exists $card->{driverrpms});
    }

    if (scalar @pkgs) {
	print <<EOF;

# Install the drivers for the network devices
EOF
	ksinstall_rpm ($config, @pkgs);
    }
}

# Prints the header functions and definitions of the post_reboot
# script.
sub kspostreboot_header
{
    my $config = shift;

    my $hostname = $config->getElement (HOSTNAME)->getValue;
    my $domain = $config->getElement (DOMAINNAME)->getValue;
    my $rootmail = $config->getElement (ROOTMAIL)->getValue;
    print <<EOF;
#!/bin/bash
# Script to run at the first reboot. It installs the base Quattor RPMs
# and runs the components needed to get the system correctly
# configured.

# Function to be called if there is an error in this phase.
# It sends an e-mail to $rootmail alerting about the failure.
fail() {
    echo "Quattor installation on  failed: \\\$1"
    sendmail -t <<End_of_sendmail
From: root\@$hostname
To: $rootmail
Subject: [\\`date +'%x %R %z'\\`] Quattor installation on $hostname failed: \\\$1

\\`cat /root/ks-post-install.log\\`
------------------------------------------------------------
\\`ls -tr /var/log/ncm 2>/dev/null|xargs tail /var/log/spma.log\\`

.
End_of_sendmail
    exit 1
}

# Function to be called if the installation succeeds.  It sends an
# e-mail to $rootmail alerting about the installation success.
success() {
    sendmail -t <<End_of_sendmail
From: root\@$hostname
To: $rootmail
Subject: [\\`date +'%x %R %z'\\`] Quattor installation on $hostname succeeded

Node $hostname successfully installed.
.
End_of_sendmail
}
hostname $hostname.$domain
# Ensure that the log file doesn't exist.
[ -e /root/ks-post-install.log ] && \\
    fail "Last installation went wrong. Aborting. See logfile"

exec &> /root/ks-post-install.log
tail -f /root/ks-post-install.log &>/dev/console &

EOF
}

# Prints the packages needed for configuring a Quattor system that
# uses SPMA.
sub ksbasepackages
{
    my $config = shift;

    ksinstall_rpm ($config, QUATTOR_LIST);
}

sub ksquattor_config
{
    my $config = shift;

    print <<EOF;

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
/usr/sbin/ncm-ncd --configure spma || fail "ncm-ncd --configure spma failed"
/usr/bin/spma --userpkgs=no --userprio=no || fail "/usr/bin/spma failed"
/usr/sbin/ncm-ncd --configure --all

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
if [ -n "\$_kernel_link_cleanup" ]; then
    rm -f "\$_kernel_link_cleanup"
fi
shutdown -r now

EOF
}


# Prints the post_reboot script.
sub post_reboot_script
{
    my ($self, $config) = @_;

    kspostreboot_header ($config);
    ksbasepackages ($config);
    ksuserhooks ($config, POSTREBOOTHOOK);
    ksquattor_config ($config);
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
        eval PART_\$d=\$dpart
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

# Prints the %post script. The post_reboot script is created inside
# this method.
sub post_install_script
{
    my ($self, $config) = @_;
    print <<EOF;

%post

# %post phase. The base system has already been installed. Let's do
# some minor changes and prepare it for being configured.

EOF

    $self->kspostreboot_hereopen;
    $self->post_reboot_script ($config);
    $self->kspostreboot_hereclose;
    ksuserhooks ($config, POSTHOOK);
    my $tree = $config->getElement (KS)->getTree;
    ksinstall_rpm ($config, @{$tree->{extra_packages}})
      if exists $tree->{extra_packages};
    ksinstall_kernels ($config);
    ksinstall_drivers ($config);
    ksuserscript ($config, POSTSCRIPT);
    if ($tree->{bootloader_location} eq "mbr") {
	ksfix_grub;
    }
    
    ## disable services, if any
    if (exists($tree->{disable_service})) {
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
/etc/rc.d/init.d/ks-post-reboot
#ln -s /etc/rc.d/init.d/ks-post-reboot /etc/rc.d/rc3.d/S86ks-post-reboot
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
}

# Closes the Kickstart file and returns everything to its normal
# state.
sub ksclose
{
    my $fh = select;
    $fh->close();
    select (STDOUT);
}

# Prints the kickstart file.
sub Configure
{
    my ($self, $config) = @_;

    my $hostname = $config->getElement (HOSTNAME)->getValue;
    if ($NoAction) {
	$self->info ("Would run " . ref ($self) . " on $hostname");
	return 1;
    }

    if ($self->ksopen ($config)) {
        $self->install ($config);
        $self->pre_install_script ($config);
        $self->post_install_script ($config);
        $self->ksclose;
    }
    return 1;
}

# Removes the KS file. To be called by --remove.
sub Unconfigure
{
    my ($self, $cfg) = @_;

    my $host = $cfg->getElement (HOSTNAME)->getValue;
    if ($NoAction) {
	$self->info ("Would run " . ref ($self) . " on $host");
	return 1;
    }

    my $domain = $cfg->getElement (DOMAINNAME)->getValue;

    my $ksdir = $main::this_app->option (KSDIROPT);
    unlink ("$ksdir/$host.$domain.ks");
    return 1;
}
