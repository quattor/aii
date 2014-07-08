# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

=pod

=head1 cmddata module

This module provides raw command data (output and exit code) and file content. 

=cut
package cmddata;

use strict;
use warnings;

# bunch of commands and their output
our %cmds;
our %files;

$cmds{disable}{cmd}='ipa aii --disable x y.z';
$cmds{install_ip}{out} = <<'EOF';
x.y.z = {'result': {'disable': True}} (options {'ip': u'5.6.7.8', 'disable': True, 'version': u'2.65'})

EOF
$cmds{install_ip}{cmd} = 'ipa aii --install --ip 5.6.7.8 x y.z';
$cmds{install_ip}{out} = <<'EOF';
randompassword = onetimepassword
x.y.z = {'result': {'modify': {'has_keytab': False, 'fqdn': (u'x.y.z',), 'has_password': True, 'krbprincipalname': (u'host/x.y.z@DUMMY',), 'managedby_host': (u'x.y.z',)}}} (options {'ip': u'5.6.7.8', 'version': u'2.65', 'install': True})
EOF

1;
