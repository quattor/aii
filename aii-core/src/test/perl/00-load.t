# -*- mode: cperl -*-
# ${license-info}
# ${author-info}
# ${build-info}

=pod

=head1 Smoke test

Basic test that ensures that our module will load correctly.

B<Do not disable this test>. And do not push anything upstream without
having run, at least, this test.

=cut

use strict;
use warnings;
use Test::More tests => 1;

use_ok("AII::shellfe");
