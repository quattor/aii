use strict;
use warnings;
use Test::More;
use Cwd qw(getcwd);

use Test::Quattor::TextRender::Component;

my $pannamespace = 'quattor/aii/opennebula';

# TODO fix in test framework
my $targetpath = getcwd() . "/target";
my $namespacepath = "$targetpath/pan";



my $t = Test::Quattor::TextRender::Component->new(
    component => 'aii-opennebula',
    pannamespace => $pannamespace,

    # TODO fix in test framework
    namespacepath => $namespacepath,
    panpath => "$namespacepath/$pannamespace",
    panunfold => 0,
    )->test();

done_testing();
