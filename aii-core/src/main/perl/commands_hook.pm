#${PMpre} AII::commands_hook${PMpost}

=pod

=head1 Hooks for customizing kickstart by inserting verbatim (bash) commands

  type aii_commands_hook = {
      "module" : string = 'commands_hooks'
      "commands" : string[]
  };

  bind "/system/aii/hooks/post_reboot/0" = aii_commands_hook;
  "/system/aii/hooks/post_reboot/0/commands" = list(
      "dmesg | tail 100",
      "lspci | grep -i vendor",
  );

  Will generate additional text in the post_reboot section of the kickstart script.

  # Start hook commands
  dmesg | tail 100
  lspci | grep -i vendor
  # End hook commands

  Be aware that certain hooks are used in e.g. bash heredoc constructions, so they might need
  extra treatment like escaping bash variables.

=cut

use strict;
use warnings;

sub new {
    my $class = shift;
    return bless {}, $class;
}


sub _print {
    my ($self, $config, $path) = @_;

    my $hook_tree = $config->getTree($path);
    my $commands = $hook_tree->{commands} || [];

    if (@$commands) {
        print "# Start hook commands\n";
        print join("\n", @$commands);
        print "\n# End hook commands\n";
    }
}


no strict 'refs';
foreach my $i (qw(pre_install pre_install_end post_reboot post_reboot_end
                  post_install_nochroot post_install anaconda pre_reboot)) {
    *{$i} = sub {
        my ($self, @args) = @_;
        return $self->_print(@args);
    }
}
use strict 'refs';
