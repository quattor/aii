use strict;
use warnings;

BEGIN {
    use Socket;
    use Sys::Hostname;
    our $hostname = hostname();

    *CORE::GLOBAL::gethostbyname = sub {
        my $name = shift;
        if ($name eq $hostname) {
            return ($name, 1, 2, 3, inet_aton("12.12.0.2"));
        } else {
            die("cannot lookup $name");
        }
    };
}

use Test::More;
use Test::MockModule;
use Test::Quattor qw(host1.example.com host2.example.com host3.example1.com host4.example.com host5.example.com host6.example1.com);
use NCM::Component::dhcp;
use CAF::FileWriter;
use CAF::Object;
use Readonly;

my $mlock = Test::MockModule->new('CAF::Lock');
my $lock = 0;
$mlock->mock('set_lock', sub {$lock++; return 1;});


my $cfg_1 = get_config_for_profile('host1.example.com');
my $cfg_2 = get_config_for_profile('host2.example.com');
my $cfg_3 = get_config_for_profile('host3.example1.com');
my $cfg_4 = get_config_for_profile('host4.example.com');
my $cfg_5 = get_config_for_profile('host5.example.com');
my $cfg_6 = get_config_for_profile('host6.example1.com');

my @configure = ($cfg_1, $cfg_2, $cfg_3, $cfg_4);

my @remove = ($cfg_1, $cfg_5, $cfg_6);

my $dhcpd = <<EOF;

host nopxe.example.com { hardware ethernet 00:22:22:22:22:01; ignore booting; }
host blacklist.example.com { hardware ethernet 00:22:22:22:02; deny booting; }

subnet 10.11.0.0 netmask 255.255.255.0 {
    option routers 10.11.0.254;
    option domain-name "example.com";
    max-lease-time 604800;
    default-lease-time 86400;

    group { # PXE
        host host100.example.com {
            hardware ethernet 00:11:22:33:44:aa;
            fixed-address 10.11.0.100;
            next-server 10.11.0.0;
        }

        host host5.example.com {  # added by aii-dhcp
            hardware ethernet 00:11:22:33:44:cc;
            fixed-address 10.11.0.5;
            next-server 10.11.0.0;
        }

        if option architecture-type = 00:09 {
            filename "grub/shim.efi";
        } else {
            filename "pxelinux";
        }
    }
}

subnet 10.11.2.0 netmask 255.255.255.0 {
    option routers 10.11.2.254;
    option domain-name "example1.com";
    max-lease-time 604800;
    default-lease-time 86400;

    group { # PXE
        host host6.example1.com {  # added by aii-dhcp
            hardware ethernet 00:11:22:33:44:bb;
        }
        if option architecture-type = 00:09 {
            filename "grub/shim.efi";
        } else {
            filename "pxelinux";
        }
    }
}
EOF

# Beware: white space is a little inconsistent currently
my $new_dhcpd = <<EOF;

host nopxe.example.com { hardware ethernet 00:22:22:22:22:01; ignore booting; }
host blacklist.example.com { hardware ethernet 00:22:22:22:02; deny booting; }

subnet 10.11.0.0 netmask 255.255.255.0 {
    option routers 10.11.0.254;
    option domain-name "example.com";
    max-lease-time 604800;
    default-lease-time 86400;

    group { # PXE

  host host4 {  # added by aii-dhcp
  	  hardware ethernet 00:11:22:33:44:99;
  	  fixed-address 10.11.0.4;
  	  next-server host0.example.com;
  	  filename "http://12.12.0.2/bootimage";
  	  option default-lease-time 259200;
option dhcp-message "Quoted string";
option domain-name-servers 8.8.4.4,8.8.8.8;

  	}

  host host2 {  # added by aii-dhcp
  	  hardware ethernet 00:11:22:33:44:66;
  	  fixed-address 10.11.0.2;
  	  next-server host0.example.com;
  	}

  host host1 {  # added by aii-dhcp
  	  hardware ethernet 00:11:22:33:44:55;
  	  fixed-address 10.11.0.1;
  	  next-server host0.example.com;
  	  option default-lease-time 259200;

  	}
        host host100.example.com {
            hardware ethernet 00:11:22:33:44:aa;
            fixed-address 10.11.0.100;
            next-server 10.11.0.0;
        }

        if option architecture-type = 00:09 {
            filename "grub/shim.efi";
        } else {
            filename "pxelinux";
        }
    }
}

subnet 10.11.2.0 netmask 255.255.255.0 {
    option routers 10.11.2.254;
    option domain-name "example1.com";
    max-lease-time 604800;
    default-lease-time 86400;

    group { # PXE

  host host3 {  # added by aii-dhcp
  	  hardware ethernet 00:11:22:33:44:88;
  	  fixed-address 10.11.2.3;
  	}
        if option architecture-type = 00:09 {
            filename "grub/shim.efi";
        } else {
            filename "pxelinux";
        }
    }
}
EOF
chomp $new_dhcpd;

# Define a few required AII options
# Normally done by aii-shellfe
our $this_app = $main::this_app;
$this_app->{CONFIG}->define("dhcpconf");
$this_app->{CONFIG}->set("dhcpconf", "/path/dhcpd.conf");
$this_app->{CONFIG}->define("restartcmd");
$this_app->{CONFIG}->set("restartcmd", "/path/my_dhcp restart");

my $comp = NCM::Component::dhcp->new('dhcp_config');

mkdir('target/test') if ! -d 'target/test';

set_file_contents('/path/dhcpd.conf', $dhcpd);

foreach my $cfg (@remove) {
   my $status = $comp->Unconfigure($cfg);
   ok($status, "Unconfigure");
}

foreach my $cfg (@configure) {
   my $status = $comp->Configure($cfg);
   ok($status, "Configure");
}

my $fh = get_file('/path/dhcpd.conf');
is("$fh", $new_dhcpd, "generated new config file");

$comp->finish();
ok(get_command('/path/my_dhcp restart'), 'dhcpd restarted');

done_testing();
