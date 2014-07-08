# ${license-info}
# ${author-info}
# ${build-info}

"""
Create AII OpenNebula plugin

- creates the 'opennebula aii' and 'opennebula aii_find' commands
"""
import re

from ipalib import Command, Bool, Str
from ipalib.plugins.dns import add_records_for_host
from ipalib.errors import AlreadyActive, AlreadyInactive

class aii(Command):  # class name has to be lowercase
    """aii command"""
    takes_args = ('shorthostname', 'domain')

    takes_options = (
        Bool('install', default=False, required=False, autofill=True,
             doc='Prepare for installation, returns random OTP',
        ),
        Bool('disable', default=False, required=False, autofill=True,
             doc='Disable the host in OpenNebula',
        ),
        Str('ip', default=None, required=False, autofill=True,
            doc='Set the IP (implies DNS configuration; don\'t use it if DNS is not enabled/wanted)'
        ),
    )

    def __init__(self, *args, **kwargs):
        """Customise the __init__ a bit"""
        super(aii, self).__init__(*args, **kwargs)
        self.fqdns = None

    def find_fqdns(self):
        """Update list of hosts"""
        res = self.Command.host_find()
        self.fqdns = {}
        for host in res['result']:
            for fqdn in host['fqdn']:
                self.fqdns[fqdn] = host
        self.log.debug('Found fqdns %s' % self.fqdns)
        self.log.debug('Found fqdns %s' % ', '.join(self.fqdns.keys()))
        return self.fqdns

    def host_in_ipa(self, hostname, force_fqdn=False):
        """Check if hostname is known in IPA"""
        if self.fqdns is None or force_fqdn:
            self.find_fqdns()
        res = hostname in self.fqdns
        if res:
            host = self.fqdns[hostname]
            self.log.debug('host %s found in IPA (has_password %s; has_keytab %s)' % (
                hostname, host['has_password'], host['has_keytab']))
        else:
            self.log.debug('host %s  NOT found in IPA' % (hostname))
        return res

    def disable_host(self, hostname):
        """Disable the host (removes keytab)"""
        res = {}
        if self.host_in_ipa(hostname):
            try:
                disable = api.Command.host_disable(hostname)
                res['disable'] = disable['result']
                self.log.debug('host_disable on %s OK.' % hostname)
            except AlreadyInactive:
                self.log.debug('Host %s already inactive.' % hostname)
        else:
            self.log.debug('No need to disable unknown host %s.' % s)

        self.log.info('Host %s disabled.' % hostname)
        return res

    def aii_install(self, hostname):
        """Take action to allow proper installation"""
        res = {}
        do_add = True
        if self.host_in_ipa(hostname):
            host = self.fqdns[hostname]
            if host['has_keytab']:
                self.log.error('Can\'t install host %s, already in IPA (disable first?)' % hostname)
                raise AlreadyActive
            else:
                self.log.debug('Host %s in IPA, but no keytab' % hostname)
                do_add = False

        if do_add:
            self.log.debug('host_add %s' % hostname)
            added = api.Command.host_add(hostname)
            res['add'] = added['result']

        # modify to set random password
        self.log.debug('host_mod %s random password' % hostname)
        # do not print/log res, it contains a password
        modified = api.Command.host_mod(hostname, random=True)
        res['modify'] = modified['result']

        return res

    def run(self, shorthostname, domain, **options):
        """
        Implemented as frontend command (ie no forward/execute)
        """
        hostname = unicode("%s.%s" % (shorthostname, domain))
        self.log.debug('AII called with hostname %s (options %s)' % (hostname, options))

        ip = options.get('ip', None)

        res = {}
        # first try to disable (e.g. in case --install=1 --disable=1 is passed)
        if options.get('disable', False):
            self.log.debug('Going to disable')
            res.update(self.disable_host(hostname))

        # check for install
        if options.get('install', False):
            self.log.debug('Going to install')
            if ip is not None:
                self.log.debug('Adding ip %s for hostname %s' % (ip, hostname))
                add_records_for_host(shorthostname, domain, [ip])
            # do not print/log res, it contains a password
            res.update(self.aii_install(hostname))

        # always return like this
        return dict(result=res)

    def output_for_cli(self, textui, result, shorthostname, domain, **options):
        if options.get('install', False) and 'modify' in result['result'] and 'randompassword' in result['result']['modify']:
            # use pop to remove it (eg in case we use it for logging)
            textui.print_plain('randompassword = %s' % (result['result']['modify'].pop('randompassword')))
        textui.print_plain('%s.%s = %r (options %s)' % (shorthostname, domain, result, options))


class aii_find(Command):  # class name has to be lowercase
    """aii_find command"""

    takes_options = (
        Bool('detail', default=False, required=False, autofill=True,
             doc='Show details',
        ),
        Bool('all', default=False, required=False, autofill=True,
             doc='Use --all option (implies detail)',
        ),
        Bool('raw', default=False, required=False, autofill=True,
             doc='Use --all --raw  option (implies detail)',
        ),
        Str('hostname', default=None, required=False, autofill=True,
            doc='Check this host (ignores hostregex)',
        ),
        Str('hostregex', default=None, required=False, autofill=True,
            doc='Show host(s) matching this regex (might be slow)',
        ),
    )

    def run(self, **options):
        """
        Show all hosts with no keytab, filtered with hostregex

        Implemented as frontend command (ie no forward/execute)
        """
        opts = {}
        opts['raw'] = options.get('raw', False)
        opts['all'] = options.get('all', False) or opts['raw']
        self.log.debug('Options all %s raw %s' % (opts['all'], opts['raw']))

        reg = None
        if 'hostname' in options:
            opts['fqdn'] = options['hostname']
            self.log.debug('Set hostname %s' % opts['fqdn'])
        elif 'hostregex' in options:
            reg = re.compile(r'' + options.get('hostregex'))
            self.log.debug('Using regexp pattern %s' % reg.pattern)

        found = self.Command.host_find(**opts)

        res = {
            'fqdns': [],
            'details' : {}
        }
        detail = options.get('detail', False) or opts['all']  # already deals with raw
        if 'result' in found and len(found['result']):
            for host in found['result']:
                fqdns = host.pop('fqdn')  # this is a tuple!
                self.log.debug('host fqdns found %s ' % (fqdns))
                for fqdn in fqdns:
                    if (reg is not None) and (not reg.search(fqdn)):
                        continue
                    res['fqdns'].append(fqdn)
                    if detail:
                        res['details'][fqdn] = host
        else:
            self.log.debug('No results from host_find')

        # sort the hostnames before returning them
        res['fqdns'].sort()

        return dict(result=res)

    def output_for_cli(self, textui, result, **options):
        detail = options.get('detail', False) or options.get('all', False) or options.get('raw', False)

        fqdns = result['result']['fqdns']
        if detail:
            # print per host details
            for fqdn in fqdns:
                textui.print_plain("Hostname %s" % (fqdn))
                details = result['result']['details'][fqdn].items()
                details.sort(key=lambda x: x[0])
                textui.print_keyval(details)
        else:
            # print list of hostnames
             textui.print_plain(" ".join(fqdns))


if __name__ == '__main__':
    from ipalib import create_api
    api = create_api()
else:
    from ipalib import api


api.register(aii)
api.register(aii_find)


if __name__ == '__main__':
    api.finalize()

    from ipalib import cli
    textui = cli.textui()

    args = [unicode('somehost'), unicode('somesubdomain.somedomain')]
    options = {
        'install': True,
    }

    result = api.Command.aii(*args, **options)
    api.Command.aii.output_for_cli(textui, result, *args, **options)

