use strict;
use warnings;
use Test::More;
use Test::Quattor qw(metaconfig modulename_exists modulename_not_exists ansible);
use AII::Shellfe;
use Cwd;
use CAF::FileReader;

use Readonly;
use File::Basename qw(basename);

my $logfile_name = basename(__FILE__);
$logfile_name =~ s/\.t$//;

# log dir
mkdir 'target/test';


Readonly my $AII_CONFIG_EMPTY => 'src/test/resources/aii-empty.conf';
Readonly my $AII_CONFIG_CERTS => 'src/test/resources/aii-certs.conf';
Readonly my $AII_LOG_FILE => "target/test/$logfile_name.log";
Readonly::Array my @SHELLFE_DEFAULT_OPTIONS => ('--logfile', $AII_LOG_FILE);

my $cli = AII::Shellfe->new('name',
                            @SHELLFE_DEFAULT_OPTIONS,
                            '--cfgfile', $AII_CONFIG_CERTS,
                            '--cert', '/some/other/path/to/cert');

is_deeply($cli->_download_options('lwp'), {
    cacert => 'test/ca_file',
    cadir => 'test/ca_dir',
    key => 'test/key_file',
    cert => '/some/other/path/to/cert',
}, "_download_options converted aii options in CAF::Download::LWP options");

is_deeply($cli->_download_options('ccm'), {
    ca_file => 'test/ca_file',
    ca_dir => 'test/ca_dir',
    key_file => 'test/key_file',
    cert_file => '/some/other/path/to/cert',
}, "_download_options converted aii options in CCM options");

# Test empty config
# must return empty hashref (so %$res works)
$cli = AII::Shellfe->new('name',
                         @SHELLFE_DEFAULT_OPTIONS,
                         '--cfgfile', $AII_CONFIG_EMPTY);
is_deeply($cli->_download_options('lwp'), {}, "empty config returns hashref for lwp");
is_deeply($cli->_download_options('ccm'), {}, "empty config returns hashref for ccm");

# Test metaconfig
my $cfg = get_config_for_profile('metaconfig');
$cli->_metaconfig("somenode", {configuration => $cfg, name => 'somename'});

my $fh = get_file(getcwd . "/target/test/cache/metaconfig/metaconfig/etc/something");
is("$fh", "a=1\n\n", "metaconfig option rendered file in cache dir");

# Test ansible
$cfg = get_config_for_profile('ansible');
$cli->_ansible("ansinode", {configuration => $cfg, name => 'ansiname'});

$fh = get_file(getcwd . "/target/test/cache/ansible/ansible/main.yml");
is("$fh", "---\n- hosts: ansinode\n  roles:\n  - ansible\n  - myalias\n", "ansible playbook rendered in cache dir");
$fh = get_file(getcwd . "/target/test/cache/ansible/ansible/roles/ansible.yml");
is("$fh", "---\n- tasks:\n  - name: mytask\n", "ansible role1 rendered in cache dir");
$fh = get_file(getcwd . "/target/test/cache/ansible/ansible/roles/myalias.yml");
is("$fh", "---\n- tasks:\n  - name: mytask\n", "ansible role2 rendered in cache dir");


# test modulename
$cfg = get_config_for_profile('modulename_not_exists');

$cli->{status} = 0;
$cli->run_plugin({configuration => $cfg}, "/system/aii/osinstall", 'Test');
is($cli->{status}, 16, "Failure");
my $text;
{local $/; open(my $fh, '<', $AII_LOG_FILE); $text = <$fh>;}
like($text, qr{ERROR.*?Couldn't load plugin module doesnotexist},
     "Failure due to osinstall module missing");

$cli->{status} = 0;
$cfg = get_config_for_profile('modulename_exists');
$cli->run_plugin({configuration => $cfg}, "/system/aii/osinstall", 'Test');
is($cli->{status}, 0, "No failure");


done_testing;
