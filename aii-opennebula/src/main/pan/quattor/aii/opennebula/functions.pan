declaration template quattor/aii/opennebula/functions;

include 'pan/types';

########################################################################
##=
## @function ip2mac
## @# generates OpenNebula MAC addresses from MAC_PREFIX + IPv4
## Based on OpenNebula ip2mac function:
## https://github.com/OpenNebula/one/blob/master/share/router/vmcontext.rb
## @syntax mac_prefix:string ipv4:string
## @param:mac_prefix hex:hex value used by oned.conf (02:00 by default)
## @param:ipv4 IP used by the VM
## @example
##=
############################################################
function ip2mac = {
    # Check arguments
    if (ARGC != 2) {
        error("usage: \"hwaddr\" = ip2mac(MAC_PREFIX, IP)");
    };
    # Sanity check
    if (!match(ARGV[0],
        '^([0-9a-f]{2}[:]){1}([0-9a-f]{2})$')) {
        error("Invalid MAC_PREFIX format ("+ARGV[0]+")");
    };
    if (!is_ipv4(ARGV[1])) {
        error("Invalid IPv4 format ("+ARGV[1]+")");
    };

    # Convert IP octets to Hex
    foreach (i; octet; split('\.',ARGV[1])) {
        array[i] = format("%02x", octet);
    };
    ip2hex = join(':', array);
    return(join(':',merge(ARGV[0], ip2hex)));
};

########################################################################
##=
## @function opennebula_replace_vm_mac
## @# replaces VM MAC addresses using OpenNebula function
##+Use the same MAC_PREFIX for OpenNebula component (oned.conf) and AII
## @syntax mac_prefix:string
## @param:mac_prefix hex:hex value used by oned.conf (02:00 by default)
## @example
##=
############################################################
function opennebula_replace_vm_mac = {
    # Check for arguments
    if (ARGC != 1) {
        error("usage: opennebula_replace_vm_mac(MAC_PREFIX)");
    };
    # Sanity check
    if (!match(ARGV[0],
        '^([0-9a-f]{2}[:]){1}([0-9a-f]{2})$')) {
        error("Invalid MAC_PREFIX format ("+ARGV[0]+")");
    };
    foreach (ethk;ethv;value("/hardware/cards/nic")) {
        if ((exists(SELF[ethk])) && 
            (exists(ethv['hwaddr']))) {
                hwaddr = ethv['hwaddr'];
                eth = ethk;
                foreach (interk;interv;value("/system/network/interfaces")) {
                    if ((exists(SELF[interk])) &&
                        (match(interk, eth))) {
                            if ((exists(interv['ip']))) {
                                mac = ip2mac(MAC_PREFIX, interv['ip']);
                                #"/hardware/cards/nic/"+eth+"/hwaddr" = mac;
                                ethv['hwaddr'] = mac;
                            }; 
                            if ((exists(interv['bridge'])) &&
                                    (exists("/system/network/interfaces/" + interv['bridge'] + "/ip"))) {
                                    mac = ip2mac(MAC_PREFIX, 
                                                 value("/system/network/interfaces"+ interv['bridge'] + "/ip"));
                                    ethv['hwaddr'] = mac;
                            };
                    };
                };
        };
    };
    return(true);
};
