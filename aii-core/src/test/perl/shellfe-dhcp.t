# -*- mode: cperl -*-
# ${license-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

BEGIN {
    use Socket;
    *CORE::GLOBAL::gethostbyname = sub {
        my $name = shift;
        if ($name =~ m/host(\d+).example(\d+)?.com/) {
            my $ip = "10.11.".(defined($2) ? $2+1 : 0).".$1";
            return ($name, 1, 2, 3, inet_aton($ip)); # 5th element is packed network address
        } else {
            die("cannot lookup $name");
        }
    };
}


use CAF::Object;
use Test::More;
use Test::Quattor;
use AII::DHCP;
use AII::Shellfe;
use Test::MockModule;
use Test::Quattor qw(shellfe-dhcp-1 shellfe-dhcp-2 shellfe-dhcp-3 shellfe-dhcp-4 shellfe-dhcp-b);

$CAF::Object::NoAction = 1;

my $mlock = Test::MockModule->new('CAF::Lock');
my $lock = 0;
$mlock->mock('set_lock', sub {$lock++; return 1;});


my $cfg_1 = { configuration => get_config_for_profile('shellfe-dhcp-1') };
my $cfg_2 = { configuration => get_config_for_profile('shellfe-dhcp-2') };
my $cfg_3 = { configuration => get_config_for_profile('shellfe-dhcp-3') };
my $cfg_4 = { configuration => get_config_for_profile('shellfe-dhcp-4') };
my $cfg_b = { configuration => get_config_for_profile('shellfe-dhcp-b') };

sub mk_node_state
{
  return map {("host$_.example".(($_ == 3 || $_ == 6) ? 1 : '').".com" => {
                                       name => "host$_.example".(($_ == 3 || $_ == 6) ? 1 : '').".com",
                                       configuration => get_config_for_profile("shellfe-dhcp-".($_ > 4 ? 'b' : $_ ))
                                      }
             )} @_;
}

my %configure = mk_node_state(1, 2, 3, 4);
my %remove = mk_node_state(1, 5, 6);

my @opts = qw(script
    --logfile target/test/shellfe-dhcp.log
    --cfgfile src/test/resources/shellfe.cfg
    --dhcpcfg src/test/resources/dhcp.cfg
    --debug 5
);


my $dhcpd = <<EOF;

subnet 10.11.0.0 netmask 255.255.255.0 {
  host host100.example.com {
    hardware ethernet 00:11:22:33:44:aa;
    fixed-address 10.11.0.100;
    next-server 10.11.0.0;
  }

  host host5.example.com {  # added by aii-dhcp
    hardware ethernet 00:11:22:33:44:cc;
    fixed-address 10.11.0.5;
    next-server 10.11.0.0;
    if () { evenmore } else {whatever};
  }

}

subnet 10.11.2.0 netmask 255.255.255.0 {
  host host6.example1.com {  # added by aii-dhcp
      hardware ethernet 00:11:22:33:44:bb;
  }
}

EOF


my $new_dhcpd = <<EOF;

subnet 10.11.0.0 netmask 255.255.255.0 {
  host host100.example.com {
    hardware ethernet 00:11:22:33:44:aa;
    fixed-address 10.11.0.100;
    next-server 10.11.0.0;
  }


  host host1.example.com {  # added by aii-dhcp
    hardware ethernet 00:11:22:33:44:55;
    fixed-address 10.11.0.1;
    next-server 10.11.0.0;
    moremore
  }

  host host2.example.com {  # added by aii-dhcp
    hardware ethernet 00:11:22:33:44:66;
    fixed-address 10.11.0.2;
    next-server 10.11.0.0;
  }

  host host4.example.com {  # added by aii-dhcp
    hardware ethernet 00:11:22:33:44:99;
    fixed-address 10.11.0.4;
    next-server 10.11.0.0;
    evenmore
  }
}

subnet 10.11.2.0 netmask 255.255.255.0 {

  host host3.example1.com {  # added by aii-dhcp
    hardware ethernet 00:11:22:33:44:88;
    fixed-address 10.11.2.3;
  }
}

EOF

# set via dhcp.cfg
set_file_contents('/path/dhcpd.conf', $dhcpd);

mkdir('target/test') if ! -d 'target/test';

my $mod = AII::Shellfe->new(@opts);

my $rem = $mod->change_dhcp('Unconfigure', %remove);
my $con = $mod->change_dhcp('Configure', %configure);
ok ($rem, 'remove returns success');
ok ($con, 'configure returns success');

is($lock, 2, "lock taken twice");

ok(get_command('/sbin/service dhcpd restart'), 'dhcpd restarted');

my $fh = get_file('/path/dhcpd.conf');
is("$fh", $new_dhcpd, "generated new config file");

done_testing();
