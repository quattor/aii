#${PMpre} AII::Role${PMpost}

use LC::Exception qw (SUCCESS);
use parent qw(CAF::Object);

use AII::Task;

# name: name of role
sub _initialize
{
    my ($self, $name, %opts) = @_;

    %opts = () if !%opts;

    $self->{log} = $opts{log} if $opts{log};

    $self->{name} = $name;
    $self->{data} = {
    };
    $self->{tasks} = [];

    return SUCCESS;
}

sub add_task
{
    my ($self, $name, $data) = @_;
    my $task = AII::Task->new($name, $data, log => $self);
    push @{$self->{tasks}}, $task;
    return $task;
}

# Generate hashref to render into yaml
sub make_data {
    my $self = shift;

    # make copy of basic data
    my $data = {%{$self->{data}}};

    # add tasks
    $data->{tasks} = [map {$_->make_data()} @{$self->{tasks}}];

    return $data;
}

1;
