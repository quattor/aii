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
use Test::MockModule;

$CAF::Object::NoAction = 1;
set_caf_file_close_diff(1);

my $mlock = Test::MockModule->new('CAF::Lock');
my $lock = 0;
$mlock->mock('set_lock', sub {$lock++; return 1;});

my @opts = qw(script
    --logfile=target/test/dhcp.log
    --cfgfile=src/test/resources/dhcp.cfg
    --configure host1.example.com --mac 00:11:22:33:44:55 --tftpserver host0.example.com --addoptions moremore
    --remove host1.example1.com
    --configurelist /path/configure_list
    --removelist /path/remove_list
);

my $cfglist = <<EOF;
host2.example.com 00:11:22:33:44:66 host0.example.com
host3.example1.com 00:11:22:33:44:88
host4.example.com 00:11:22:33:44:99 host0.example.com evenmore

EOF

my $rmlist = <<EOF;
host5.example.com
host6.example1.com
EOF

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

set_file_contents('/path/configure_list', $cfglist);
set_file_contents('/path/remove_list', $rmlist);
# set via dhcp.cfg
set_file_contents('/path/dhcpd.conf', $dhcpd);

mkdir('target/test') if ! -d 'target/test';

my $mod = AII::DHCP->new(@opts);
ok(! $mod->configure(), 'configure returns success');

is($lock, 1, "lock taken");

diag explain $mod->{NTC};
is_deeply($mod->{NTC}, [
  {
    'FQDN' => 'host1.example.com',
    'IP' => 168493057,
    'MAC' => '00:11:22:33:44:55',
    'MORE_OPT' => 'moremore',
    'NAME' => 'host1.example.com',
    'OK' => 1,
    'ST_IP' => '10.11.0.1',
    'ST_IP_TFTP' => '10.11.0.0'
  },
  {
    'FQDN' => 'host2.example.com',
    'IP' => 168493058,
    'MAC' => '00:11:22:33:44:66',
    'MORE_OPT' => '',
    'NAME' => 'host2.example.com',
    'OK' => 1,
    'ST_IP' => '10.11.0.2',
    'ST_IP_TFTP' => '10.11.0.0'
  },
  {
    'FQDN' => 'host3.example1.com',
    'IP' => 168493571,
    'MAC' => '00:11:22:33:44:88',
    'MORE_OPT' => '',
    'NAME' => 'host3.example1.com',
    'OK' => 1,
    'ST_IP' => '10.11.2.3',
    'ST_IP_TFTP' => undef
  },
  {
    'FQDN' => 'host4.example.com',
    'IP' => 168493060,
    'MAC' => '00:11:22:33:44:99',
    'MORE_OPT' => 'evenmore',
    'NAME' => 'host4.example.com',
    'OK' => 1,
    'ST_IP' => '10.11.0.4',
    'ST_IP_TFTP' => '10.11.0.0'
  }
], "nodes to configure");

diag explain $mod->{NTR};
is_deeply($mod->{NTR}, [
  {
    'FQDN' => 'host1.example1.com',
    'IP' => '10.11.2.1',
    'NAME' => 'host1.example1.com'
  },
  {
    'FQDN' => 'host5.example.com',
    'IP' => '10.11.0.5',
    'NAME' => 'host5.example.com'
  },
  {
    'FQDN' => 'host6.example1.com',
    'IP' => '10.11.2.6',
    'NAME' => 'host6.example1.com'
  }
], "nodes to remove");

ok(get_command('/sbin/service dhcpd restart'), 'dhcpd restarted');

my $fh = get_file('/path/dhcpd.conf');
is("$fh", $new_dhcpd, "generated new config file");

done_testing();
