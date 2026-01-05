package NCM::Component::ansible;

sub new {
    my $class = shift;

    return bless {}, $class;
}

sub ansible_command {
    my ($self, $configuration) = @_;
    $configuration->{ansible}->{role}->add_task("mytask");
    return 1;  # must return success
}

1;
