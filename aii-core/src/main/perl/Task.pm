#${PMpre} AII::Task${PMpost}

use LC::Exception qw (SUCCESS);
use parent qw(CAF::Object);

# name: name of task
sub _initialize
{
    my ($self, $name, $data, %opts) = @_;

    %opts = () if !%opts;

    $self->{log} = $opts{log} if $opts{log};

    $self->{name} = $name;
    $self->{data} = $data || {};

    return SUCCESS;
}

# Generate hashref to render into yaml
sub make_data {
    my $self = shift;

    # make copy of basic data
    my $data = {%{$self->{data}}};

    # add tasks
    $data->{name} = $self->{name};

    return $data;
}

1;
