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
    my $password = $Config->{rpc}->{password} || "myfancypass";

    if (! $password ) {
        $main::this_app->error("No password set in configfile $filename.");
        return;
    }
    
    my $one = Net::OpenNebula->new(
        url      => "http://$host:$port/RPC2",
        user     => $user,
        password => $password,
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
	        $main::this_app->verbose("Adding imagename $imagename",
		                		     " with datastore $datastore");
	        $res{$imagename}{image} = $image;
	        $res{$imagename}{datastore} = $datastore;
	    } else {
	    # Shouldn't happen; fields are in TT
	        $main::this_app->error("No datastore and/or imagename for image data $image.");
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

    #$main::this_app->info("This is my template: $vm_template.");
    return $vm_template
}


sub new
{
    my $class = shift;
    return bless {}, $class;
}

# Performs VM install wich:
# - Creates a new hds for each $ harddisks in your datastore using the imagetemplate file
# - Instantiates a new VM using the quattor vmtemplate
# $ oneimage create -d 103 --name "node640.cubone.os_vda" --type DATABLOCK --size 40960 --prefix vd --description "one/QUATTOR_IMAGE001" --persistent 
# Create VM template
# $ onetemplate create $vmtemplate
# Instantiate the new VM
# $ onetemplate instantiate $fqan --name $fqan
sub opennebula_aii_vminstantiate
{
    my ($self, $one, $fqdn, $instantiatevm) = @_;
    if ($instantiatevm) {
        return undef;
    }

    return undef;
}

# Check if VM image/s exists
# and it remove/create a new one
sub opennebula_aii_vmimage
{
    my ($self, $one, $forcecreateimage, %images) = @_;
    
    # Check if the image already exists
    # and remove it if is required

    while ( my ($imagename, %imagedata) = each %images) {
        $main::this_app->info ("Checking ONE image: $imagename ...");

        my @existimage = $one->get_images(qr{^$imagename$});
        foreach my $t (@existimage) {
            if (($t->{extended_data}->{TEMPLATE}->[0]->{QUATTOR}->[0]) && ($forcecreateimage)) {
            }

        }

            

        # Missing get_image function
        my $vmimage;
        #$vmimage = $one->get_image($imagename);

        # TODO: Check that QUATTOR = 1
        if ($vmimage) {
            if ($forcecreateimage) {
                # Remove the image
                #$vmimage->delete();

                # And generate the new one
                #$vmimageid = $one->create_image(%imagedata);
            }

        }


    }

}

sub opennebula_aii_vmrunning
{
    my ($self, $one, $fqdn) = @_;
    
    my @runningvms = $one->get_vms(qr{^$fqdn$});

    # TODO: check if the running $fqdn has QUATTOR = 1 
    # if not don't touch it!!
    foreach my $t (@runningvms) {
        if ($t->{extended_data}->{TEMPLATE}->[0]->{QUATTOR}->[0]) {
            # Die!!
            $main::this_app->info("Running VM will be stopped: $t->name");
            $t->delete();
        }
    }
}

# This function creates/removes VM templates if is required
sub opennebula_aii_vmtemplate
{
    my ($self, $one, $fqdn, $createvmtemplate, $vmtemplate) = @_;
    
    # Check if the vm template already exists
    #my $reg = "^$fqdn\$";
    my @existtmpls = $one->get_templates(qr{^$fqdn$});

    foreach my $t (@existtmpls) {
        if (($t->{extended_data}->{TEMPLATE}->[0]->{QUATTOR}->[0]) && ($createvmtemplate)) {
            $main::this_app->info("QUATTOR VM template, going to delete: $t->name");
            $t->delete();
        }
    }

    if ($createvmtemplate) {
        my $templ = $one->create_template($vmtemplate);
        $main::this_app->info("New ONE VM template: $templ");
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
    my $datastore = $tree->{datastore};

    my $hostname = $config->getElement ('/system/network/hostname')->getValue;
    my $domainname = $config->getElement ('/system/network/domainname')->getValue;

    my @disks = $config->getElement ('/system/hardware/harddisks')->getValue;
    my $fqdn = "$hostname.$domainname";

    my $one = make_one();

    $main::this_app->info("Create image $forcecreateimage into datastore: $datastore");

    # Check if the VM is still running, if so we stop it
    $self->opennebula_aii_vmrunning($one,$fqdn);

    # Check VM image/s status
    # if exixts...
    # then we remove the image/s...
    # and we create a new one
    $self->opennebula_aii_vmimage($one,$fqdn,$forcecreateimage,@disks);
    
    # Finally we remove/create a VM template
    #my $vmtemplate = $self->opennebula_aii_vmtemplate($fqdn,$createvmtemplate);

    # Get the VM template first
    my $vmtemplate = $self->get_vmtemplate($config);
    # Remove/Create if it's required
    my $vmtemplateid = $self->opennebula_aii_vmtemplate($one,$fqdn,$createvmtemplate,$vmtemplate);

    # and instantiate the VM
    # if $instantiatevm is set
    my $vmid = $self->opennebula_aii_vminstantiate($one,$fqdn,$instantiatevm);

}


# Performs VM remove wich depending on the booleans:
# removes running VM: $ onevm delete $fqdn
# removes VM template: $ onetemplate delete $fqdn
# removes VM image for each $harddisks: $ oneimage delete $fqdn_$harddisks
sub remove
{
    my ($self, $config, $path) = @_;
    my $tree = $config->getElement($path)->getTree();
    my $forcecreateimage = $tree->{image};
    my $instantiatevm = $tree->{vm};
    my $createvmtemplate = $tree->{template};
    my $datastore = $tree->{datastore};

    my $hostname = $config->getElement ('/system/network/hostname')->getValue;
    my $domainname = $config->getElement ('/system/network/domainname')->getValue;

    my $fqdn = "$hostname.$domainname";
    my $remove = 1;

    my $one = make_one();

    # Stop the VM
    $self->opennebula_aii_vmrunning($one,$fqdn);

    # Remove the images
    my %images = $self->get_images($config);
    $self->opennebula_aii_vmimage($one,$forcecreateimage,%images);

    # Remove VM templates, get the VM template name first
    my $vmtemplate = $self->get_vmtemplate($config);
    $self->opennebula_aii_vmtemplate($one,$fqdn,$createvmtemplate,$vmtemplate);
    #my $vmtemplate = $self->opennebula_aii_vmtemplate($fqdn,$createvmtemplate);

}


1;
