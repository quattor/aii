package NCM::Component::doesexist;

sub new {
    my $class = shift;

    return bless {}, $class;
}

sub Test {1};

1;
