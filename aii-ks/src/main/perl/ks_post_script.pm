#${PMpre} NCM::Component::ks_post_script${PMpost}

# Generate a the ks post section of a node as a standalone script.

use parent qw (NCM::Component::ks);

use CAF::FileWriter;
use NCM::Component::ks qw(get_fqdn);

sub _ks_filename
{
    my ($self, $ksdir, $fqdn) = @_;
    return "$ksdir/kickstart_post_$fqdn.sh";
}

# Cancels the open filewriter instance on the script
#   and returns everything (the select magic/hack) to its normal state.
# Returns the content of the cancelled filewriter instance
sub ksclose
{
    my $fh = select;

    my $text = "$fh";

    select (STDOUT);

    $fh->cancel();
    $fh->close();

    return "$text";
}

sub make_script
{
    my ($self, $cfg, $post_script) = @_;

    my $fh = CAF::FileWriter->open($self->ks_filename($cfg), mode => 0755, log => $self);
    print $fh $post_script;
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

    $self->ksopen($config);

    # ignore the packages that are treated in install for now
    #   for now assume, all is there already
    # this is not kickstart
    #    won't generate the POSTNOCHROOTHOOK
    #    no repos passed
    $self->post_install_script ($config, [], {}, 0);

    my $post_script = $self->ksclose();

    $self->make_script($config, $post_script);

    return 1;
}


1;
