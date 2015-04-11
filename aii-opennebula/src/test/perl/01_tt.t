use strict;
use warnings;
use Test::More;
use Cwd qw(getcwd);

use Test::Quattor::TextRender::Component;

my $t = Test::Quattor::TextRender::Component->new(
    component => 'aii-opennebula',
    pannamespace => 'quattor/aii/opennebula',
    )->test();

done_testing();
