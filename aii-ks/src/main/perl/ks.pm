# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
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
use FileHandle;
use LC::Exception qw (throw_error);
use Data::Dumper;
use Exporter;
use CAF::FileWriter;
use Sys::Hostname;

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
               KERNELVERSION    => "/system/kernel/version",
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
               LOCALHOST        => hostname(),
               ENABLE_SSHD      => "enable_sshd",
           };

# Base package path for user hooks.
use constant   MODULEBASE       => "AII::";
use constant   USEMODULE        => "use " . MODULEBASE;

# Configuration variable for the osinstall directory.
use constant   KSDIROPT         => 'osinstalldir';

# Packages to be installed when setting up Quattor.


# Packages containing kernels. kernel-xen is not listed here, as it
# depends on different versions of mkinitrd and e2fsprogs, and
# installing them may cause a dependency hell.
use constant KERNELLIST         => qw (kernel-firmware kernel kernel-smp);


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

    my $mtu = exists($net->{mtu}) ? "--mtu=$net->{mtu} " : "";

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
network --bootproto=static --ip=$net->{ip} --netmask=$net->{netmask} $gw --nameserver=$ns --device=$dev --hostname=$fqdn $mtu
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
sub kscommands
{
    my  $config = shift;

    my $tree = $config->getElement(KS)->getTree;

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
text
reboot
$installtype
timezone --utc $tree->{timezone}
rootpw --iscrypted $tree->{rootpw}
EOF

    if ($tree->{enable_sshd}) {
        print "sshpw  --username=root $tree->{rootpw} --iscrypted \n";
    }

    if (exists($tree->{logging})) {
        print "logging --host=$tree->{logging}->{host} ",
            "--port=$tree->{logging}->{port}";
        print " --level=$tree->{logging}->{level}" if $tree->{logging}->{level};
        print "\n";
    }
    print "bootloader  --location=$tree->{bootloader_location}";
    print " --driveorder=", join(',', @{$tree->{bootdisk_order}})
        if exists $tree->{bootdisk_order} && @{$tree->{bootdisk_order}};
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
    print "auth ", join(" ", map("--$_",  @{$tree->{auth}})), "\n";
    print "lang $tree->{lang}\n";
    print "langsupport ", join (" ", @{$tree->{langsupport}}), "\n"
        if exists $tree->{langsupport} and @{$tree->{langsupport}}[0] ne "none";

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
    print "%packages ", join(" ",@{$tree->{packages_args}}), "\n",
        join ("\n", @{$tree->{packages}}), "\n";

}

# Writes the mountpoint definitions and LVM and MD settings
sub ksmountpoints
{
    my $config = shift;

    # Skip the remainder if "/system/filesystems" is undefined
    return unless ( $config->elementExists (FS) );

    my $tree = $config->getElement(KS)->getTree;
    my %ignoredisk;
    if (exists ($tree->{ignoredisk}) &&
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
        next if (exists $fstree->{block_device}->{holding_dev} &&
                 exists $ignoredisk{$fstree->{block_device}->{holding_dev}->{devname}});
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

    print <<'EOF';
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
exec >/tmp/pre-log.log 2>&1
tail -f /tmp/pre-log.log > /dev/console &
set -x

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
    local path clear SIZE START
    path="$1"
    clear="$2"

    SIZE=`fdisk -s "$path"`
    let START=$SIZE/1024-$clear
    dd if=/dev/zero of="$path" bs=1M count=$clear 2>/dev/null
    dd if=/dev/zero of="$path" bs=1M seek=$START 2>/dev/null
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

    print "yum -c /tmp/aii/yum/yum.conf -y install ", join("\\\n    ", @pkgs),
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
        if (exists $spma->{proxyport}) {
            $proxyport = $spma->{proxyport};
        }
        if (exists $spma->{proxytype}) {
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
set -x

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

    my $obsoletes = $config->getElement (SPMA_OBSOLETES)->getTree();
    my $repos = $config->getElement (REPO)->getTree();

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

    foreach my $repo (@$repos) {
        if ($ptype && $ptype eq 'reverse') {
            $repo->{protocols}->[0]->{url} =~ s{://.*?/}{$phost:$pport};
        }
        print <<EOF;
[$repo->{name}]
enabled=1
baseurl=$repo->{protocols}->[0]->{url}
name=$repo->{name}
gpgcheck=0
skip_if_unavailable=1
EOF
        if ($ptype && $ptype eq 'forward') {
            print <<EOF;
proxy=http://$phost:$pport/
EOF
        }

        if (exists($repo->{priority})) {
            print <<EOF;
priority=$repo->{priority}
EOF
        }
    }

    print "end_of_repos\n";
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
        return @ret;
    }

    return $pkg;
}


sub yum_install_packages
{
    my ($self, $config) = @_;

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
            push (@pkgs, $self->process_pkgs($pkgst, $st));
        }
    }
    ksinstall_rpm(@pkgs);
}

# Prints the %post script. The post_reboot script is created inside
# this method.
sub post_install_script
{
    my ($self, $config) = @_;
    print <<EOF;

%post

set -x
# %post phase. The base system has already been installed. Let's do
# some minor changes and prepare it for being configured.

exec &>/tmp/post-log.log
tail -f /tmp/post-log.log > /dev/console &

EOF

    $self->kspostreboot_hereopen;
    $self->post_reboot_script ($config);
    $self->kspostreboot_hereclose;
    ksuserhooks ($config, POSTHOOK);
    my $tree = $config->getElement (KS)->getTree;
    $self->yum_setup ($config);
    $self->yum_install_packages ($config);
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
    print "$end\n";

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

    my $hostname = $config->getElement (HOSTNAME)->getValue;
    if ($NoAction) {
        $self->info ("Would run " . ref ($self) . " on $hostname");
        return 1;
    }

    $self->ksopen ($config);
    $self->install ($config);
    $self->pre_install_script ($config);
    $self->post_install_script ($config);
    $self->ksclose;
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
