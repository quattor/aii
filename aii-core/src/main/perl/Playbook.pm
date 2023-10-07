#${PMpre} AII::Playbook${PMpost}

use LC::Exception qw (SUCCESS);
use parent qw(CAF::Object);
use CAF::TextRender;
use CAF::Path;

use AII::Role;

# hosts: playbook hosts
sub _initialize
{
    my ($self, $hosts, %opts) = @_;

    %opts = () if !%opts;

    $self->{log} = $opts{log} if $opts{log};

    $self->{data} = {
        hosts => $hosts
    };
    $self->{roles} = [];

    return SUCCESS;
}

sub add_role
{
    my ($self, $name) = @_;
    my $role = AII::Role->new($name, log => $self);
    push @{$self->{roles}}, $role;
    return $role;
}


# Generate hashref to render into yaml
sub make_data {
    my $self = shift;

    # make copy of basic data
    my $data = {%{$self->{data}}};

    # add roles
    $data->{roles} = [map {$_->{name}} @{$self->{roles}}];

    return $data;
}

# Generate playbook and roles
# root: base working dir
sub write
{
    my ($self, $root) = @_;

    # Make roles subdir in root
    my $cafpath = CAF::Path::mkcafpath(log => $self);
    $cafpath->directory("$root/roles");

    # Generate all roles and playbook data
    my $files = {
        main => $self->make_data()
    };

    foreach my $role (@{$self->{roles}}) {
        $files->{"roles/$role->{name}"} = $role->make_data();
    }

    # Write
    foreach my $filename (sort keys %$files) {
        my $trd = CAF::TextRender->new(
            'yamlmulti',
            {'host' => [$files->{$filename}]},  # use yamlmulti to bypass arrayref issue
            log => $self,
            );
        my $fh = $trd->filewriter(
            "$root/$filename.yml",
            log => $self,
            );
        $fh->close();
    };
}

1;
