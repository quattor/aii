package OpennebulaMock;

use Test::MockModule;
use Test::More;
use Data::Dumper;
use base 'Exporter';

our @EXPORT = qw(rpc_history_reset rpc_history_ok diag_rpc_history);


my @rpc_history = ();
my @rpc_history_full = ();


sub dump_rpc {
    return Dumper(\@rpc_history);
}

sub diag_rpc_history {
    diag("DEBUG rpc_history ".join(", ", @rpc_history));
};

# similar to Test::Quattor::command_history_reset
sub rpc_history_reset {
    @rpc_history = ();
    @rpc_history_full = ();
}

# similar to Test::Quattor::command_history_ok
sub rpc_history_ok {
    my $rpcs = shift;

    my $lastidx = -1;
    foreach my $rpc (@$rpcs) {
        # start iterating from lastidx+1
        my ( $index )= grep { $rpc_history[$_] =~ /$rpc/  } ($lastidx+1)..$#rpc_history;
        return 0 if !defined($index) or $index <= $lastidx;
        $lastidx = $index;
    };
    # in principle, when you get here, all is ok.                                                                                                                                        
    # but at least 1 command should be found, so lastidx should be > -1                                                                                                                  

    return $lastidx > -1;
    
}

sub mock_rpc {
    my ($self, $method, @params) = @_;
    push(@rpc_history, $method);
    push(@rpc_history_full, [$method, @params]);
    return (); # return empty list
};

our $opennebula = new Test::MockModule('Net::OpenNebula');
$opennebula->mock( '_rpc',  \&mock_rpc);




1;

