package OpennebulaMock;

use Test::MockModule;

use Data::Dumper;

our @rpc = ();


sub dump_rpc {
    return Dumper(\@rpc);
}

sub mock_rpc {
    my ($self, $method, @params) = @_;
    push(@rpc, [$method, @params]);
    return (); # return empty list
};

our $opennebula = new Test::MockModule('Net::OpenNebula');
$opennebula->mock( '_rpc',  \&mock_rpc);




1;

