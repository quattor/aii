use strict;
use warnings;
use Test::More;
use Test::MockModule;
use Cwd;
use Data::Dumper;

use Test::Quattor::TextRender::Component;

my $t = Test::Quattor::TextRender::Component->new(
    pannamespace => 'metaconfig/opennebula',
    )->test();

done_testing();
