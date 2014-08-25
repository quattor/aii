# ${license-info}
# ${developer-info}
# ${author-info}

package AII::opennebula;

use strict;
use warnings;
use CAF::Process;
use Template;

use Config::Tiny;
use Net::OpenNebula;
use Data::Dumper;

use constant TEMPLATEPATH => "/usr/share/templates/quattor";
use constant AII_OPENNEBULA_CONFIG => "/etc/aii/opennebula.conf";
use constant HOSTNAME => "/system/network/hostname";
use constant DOMAINNAME => "/system/network/domainname";
use constant TIMEOUT => 60;

# a config file in .ini style with minmal 
#   [rpc]
#   password=secret
sub make_one 
{
    my $self = shift;
    my $filename = shift || AII_OPENNEBULA_CONFIG;

    if (! -f $filename) {
        $main::this_app->error("No configfile $filename.");
        return;
    }

    my $Config = Config::Tiny->new;

    $Config = Config::Tiny->read($filename);
    my $port = $Config->{rpc}->{port} || 2633;
    my $host = $Config->{rpc}->{host} || "localhost";
    my $user = $Config->{rpc}->{user} || "oneadmin";
    my $password = $Config->{rpc}->{password};

    if (! $password ) {
        $main::this_app->error("No password set in configfile $filename.");
        return;
    }
    
    my $one = Net::OpenNebula->new(
        url      => "http://$host:$port/RPC2",
        user     => $user,
        password => $password,
        log => $main::this_app,
        fail_on_rpc_fail => 0,
    );
    return $one;
}


sub process_template 
{
    my ($self, $config, $tt_name) = @_;
    my $res;
    
    my $tt_rel = "metaconfig/opennebula/$tt_name.tt";
    my $tree = $config->getElement('/')->getTree();
    my $tpl = Template->new(INCLUDE_PATH => TEMPLATEPATH);
    if (! $tpl->process($tt_rel, $tree, \$res)) {
	    $main::this_app->error("TT processing of $tt_rel failed:", 
			                  $tpl->error());
	    return;
    }
    return $res;
}

# Return fqdn of the node
sub get_fqdn
{
    my ($self,$config) = @_;
    my $hostname = $config->getElement (HOSTNAME)->getValue;
    my $domainname = $config->getElement (DOMAINNAME)->getValue;
    return "${hostname}.${domainname}";
}


# It gets the image template from tt file
# and gathers image names format: <fqdn>_<vdx> 
# and datastore names to store the new images 
sub get_images
{
    my ($self, $config) = @_;
    my $all_images = $self->process_template($config, "imagetemplate");
    my %res;

    my @tmp = split(qr{^DATASTORE\s+=\s+(?:"|')(\S+)(?:"|')\s*$}m, $all_images);

    while (my ($image,$datastore) = splice(@tmp, 0, 2)) {
	    my $imagename = $1 if ($image =~ m/^NAME\s+=\s+(?:"|')(.*?)(?:"|')\s*$/m);
	    if ($datastore && $imagename) {
	        $main::this_app->verbose("Detected imagename $imagename",
		                		     " with datastore $datastore");
	        $res{$imagename}{image} = $image;
	        $res{$imagename}{datastore} = $datastore;
            $main::this_app->debug(3, "This is image template $imagename: $image");

	    } else {
	        # Shouldn't happen; fields are in TT
	        $main::this_app->error("No datastore and/or imagename for image data $image.");
	    };
    }

    return %res;
}

# It gets the vnet leases from tt file
# and gathers vnet names and IPs/MAC addresses
sub get_vnetleases
{
    my ($self, $config) = @_;
    my $all_leases = $self->process_template($config, "vnetleases");
    my %res;

    my @tmp = split(qr{^NETWORK\s+=\s+(?:"|')(\S+)(?:"|')\s*$}m, $all_leases);

    while (my ($lease,$network) = splice(@tmp, 0 ,2)) {

        if ($network && $lease) {
            $main::this_app->verbose("Detected vnet lease: $lease",
                                     " within network $network");
            $res{$network}{lease} = $lease;
            $res{$network}{network} = $network;
            $main::this_app->debug(3, "This is vnet lease template for $network: $lease");

        } else {
            # No leases found for this VM
            $main::this_app->error("No leases and/or network info $lease.");
        };
    }
    return %res;
}

sub get_vmtemplate
{
    my ($self, $config) = @_;
    my $vm_template = $self->process_template($config, "vmtemplate");
    my $vmtemplatename = $1 if ($vm_template =~ m/^NAME\s+=\s+(?:"|')(.*?)(?:"|')\s*$/m);

    if ($vmtemplatename) {
        $main::this_app->verbose("The VM template name: $vmtemplatename.");
    } else {
        # VM template name is mandatory
        # TODO: we have to check QUATTOR variable as well
        $main::this_app->error("No VM template name found.");
        return undef;
    };

    $main::this_app->debug(3, "This is vmtemplate $vmtemplatename: $vm_template.");
    return $vm_template
}


sub new
{
    my $class = shift;
    return bless {}, $class;
}


# Check if VM image/s exists
# and it remove/create a new one
sub opennebula_aii_vmimage
{
    my ($self, $one, $forcecreateimage, $imagesref, $remove) = @_;

    while ( my ($imagename, $imagedata) = each %{$imagesref}) {
        $main::this_app->info ("Checking ONE image: $imagename ...");

        my @existimage = $one->get_images(qr{^$imagename$});
        foreach my $t (@existimage) {
             if (($t->{extended_data}->{TEMPLATE}->[0]->{QUATTOR}->[0]) && ($forcecreateimage)) {
               
                # It's safe, we can remove the image
                $t->delete();

            }

        }

        # TODO deal with images  that have same name but bot QUATTOR tag set (or set to 0).
        # we should just skip the creation then and fail hard?

    	# And create the new image with the image data
    	if (!$remove) {
    	    my $newimage = $one->create_image($imagedata->{image}, $imagedata->{datastore});
    	    return $newimage;
    	}

    }
    return undef;

}

# Check if VNET lease exists
# and it add/remove a new one
sub opennebula_aii_vnetleases
{
    my ($self, $one, $leasesref, $remove) = @_;
    while ( my ($vnet, $leasedata) = each %{$leasesref}) {
        $main::this_app->info ("Testing ONE vnet lease: $vnet ...");

        my @existlease = $one->get_vnets(qr{^$vnet$});
        foreach my $t (@existlease) {
            if ($remove) {
                $t->rmleases($leasedata->{lease});
            } else {
                $t->addleases($leasedata->{lease});
            };

        }
    }
    return undef;

}


# This function stops/removes running VMs based on fqdn names
# and if QUATTOR flag is set
sub opennebula_aii_vmrunning
{
    my ($self, $one, $fqdn) = @_;
    
    my @runningvms = $one->get_vms(qr{^$fqdn$});

    # check if the running $fqdn has QUATTOR = 1 
    # if not don't touch it!!
    foreach my $t (@runningvms) {
        if ($t->{extended_data}->{USER_TEMPLATE}->[0]->{QUATTOR}->[0]) {
            # Die!!
            $main::this_app->info("Running VM will be removed: $t->name");
            $t->delete();
        }
    }
}

# This function creates/removes VM templates if is required
sub opennebula_aii_vmtemplate
{
    my ($self, $one, $fqdn, $createvmtemplate, $vmtemplate, $remove) = @_;
    
    # Check if the vm template already exists
    my @existtmpls = $one->get_templates(qr{^$fqdn$});

    foreach my $t (@existtmpls) {
        if (($t->{extended_data}->{TEMPLATE}->[0]->{QUATTOR}->[0]) && ($createvmtemplate)) {
            $main::this_app->info("QUATTOR VM template, going to delete: ",$t->name);
            $t->delete();
        }
    }
    
    # TODO extract the IP, MAC and VNET and create them
    
    if (($createvmtemplate) && (!$remove)) {
        my $templ = $one->create_template($vmtemplate);
        $main::this_app->debug(1, "New ONE VM template: $templ");
        return $templ;
    }
    
}


sub install
{
    my ($self, $config, $path) = @_;

    my $tree = $config->getElement($path)->getTree();

    my $forcecreateimage = $tree->{image};
    my $instantiatevm =	$tree->{vm};
    my $createvmtemplate = $tree->{template};
    my $onhold = $tree->{onhold};
    my $fqdn = $self->get_fqdn($config);

    my $one = make_one();

    # Check if the VM is still running, if so we stop it
    $self->opennebula_aii_vmrunning($one, $fqdn);

    # Check VM image/s status
    # if exixts...
    # then we remove the image/s...
    # and we create a new one
    my %images = $self->get_images($config);

    $self->opennebula_aii_vmimage($one, $forcecreateimage, \%images);

    # Check network leases
    # add/remove leases on demand
    my %leases = $self->get_vnetleases($config);

    $self->opennebula_aii_vnetleases($one, \%leases);

    
    # Get the VM template first
    my $vmtemplatetxt = $self->get_vmtemplate($config);
    # Remove/Create if it's required
    my $vmtemplate = $self->opennebula_aii_vmtemplate($one, $fqdn, $createvmtemplate, $vmtemplatetxt);

    # and instantiate the template, returns the VM instance
    # if $instantiatevm is set
    if ($instantiatevm) {
    	$main::this_app->debug(1, "Instantiate vm with name $fqdn with template ", $vmtemplate->name);
    	
        # Check that image is in READY state.
        my @myimages = $one->get_images(qr{^${fqdn}\_vd[a-z]$});
        foreach my $t (@myimages) {

                my $imagestate = $t->state();
                # If something wrong happens set a timeout 
                eval { 
                    local $SIG{ALRM} = sub { die "alarm\n" };
                    alarm TIMEOUT;
                    while($imagestate ne "READY") {
                        $main::this_app->info("VM Image status: ${imagestate} , waiting 5 seconds...");
                        sleep 5;
                        $imagestate = $t->state();
                    }
                    alarm 0;
                };
                if ($@) {
                    die unless $@ eq "alarm\n"; #timeout!
                    $main::this_app->error("TIMEOUT! Image status: ${imagestate} after ".TIMEOUT." seconds...");
                }
                else {
                    $main::this_app->info("VM Image status: ${imagestate} ,OK");
                }
        }

        my $vmid = $vmtemplate->instantiate(name => $fqdn, onhold => $onhold);
    }
    
}

# Performs Quattor post_reboot
# ACPID service is mandatory for ONE VMs 
sub post_reboot
{
    my ($self, $config, $path) = @_;
    my $tree = $config->getElement($path)->getTree();

    print <<EOF;
yum install -y acpid

service acpid start
EOF

}

# Performs VM remove wich depending on the booleans
# Stops running VM
# Removes VM template
# Removes VM image for each $harddisks
# Removes vnet leases
sub remove
{
    my ($self, $config, $path) = @_;
    my $tree = $config->getElement($path)->getTree();
    #my $forcecreateimage = $tree->{image};
    my $forcecreateimage = 1;
    #my $createvmtemplate = $tree->{template};
    my $createvmtemplate = 1;
    #my $datastore = $tree->{datastore};
    my $fqdn = $self->get_fqdn($config);
    my $remove = 1;

    my $one = make_one();

    # Stop/remove the running VM
    $self->opennebula_aii_vmrunning($one,$fqdn);

    # Remove the images
    my %images = $self->get_images($config);
    if (%images) {
        $self->opennebula_aii_vmimage($one, $forcecreateimage, \%images, $remove);
    }

    # Remove network leases
    my %leases = $self->get_vnetleases($config);
    if (%leases) {
        $self->opennebula_aii_vnetleases($one, \%leases, $remove);
    }

    # Remove VM templates, get the VM template name first
    my $vmtemplatetxt = $self->get_vmtemplate($config);
    if ($vmtemplatetxt) {
        $self->opennebula_aii_vmtemplate($one, $fqdn, $createvmtemplate, $vmtemplatetxt, $remove);
    }

}


1;
