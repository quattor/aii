declaration template quattor/aii/opennebula/functions;

include 'pan/types';

@documentation{
This function generates OpenNebula MAC addresses from MAC_PREFIX + IPv4
Based on OpenNebula opennebula_ipv42mac function:

https://github.com/OpenNebula/one/blob/master/share/router/vmcontext.rb

Syntax: 
mac_prefix:string ipv4:string

mac_prefix hex:hex value used also by oned.conf (02:00 by default)
ipv4 IP used by the VM
}
function opennebula_ipv42mac = {
    # Check arguments
    if (ARGC != 2) {
        error("usage: \"hwaddr\" = opennebula_ipv42mac(MAC_PREFIX, IP)");
    };
    # Sanity check
    if (!match(ARGV[0],
        '^[0-9a-f]{2}[:][0-9a-f]{2}$')) {
        error(format("Invalid MAC_PREFIX format: %s", ARGV[0]));
    };
    if (!is_ipv4(ARGV[1])) {
        error(format("Invalid IPv4 format: %s", ARGV[1]));
    };
    # Convert IP octets to Hex
    ipoctets = list();
    macaddr = ARGV[0];
    foreach (i; octet; split('\.',ARGV[1])) {
        macaddr = format("%s:%02x", macaddr, to_long(octet));
    };
    return(macaddr);
};

@documentation{
This function replaces nic hwaddr using OpenNebula MAC function
Use the same MAC_PREFIX for OpenNebula component (oned.conf) and AII

Syntax: 
mac_prefix:string

mac_prefix hex:hex value used by oned.conf

Example:
"/hardware/cards/nic" = opennebula_replace_vm_mac(MAC_PREFIX);
}
function opennebula_replace_vm_mac = {
    # Check for arguments
    if (ARGC != 1) {
        error("usage: opennebula_replace_vm_mac(MAC_PREFIX)");
    };
    # Sanity check
    if (!match(ARGV[0],
        '^[0-9a-f]{2}[:][0-9a-f]{2}$')) {
        error(format("Invalid MAC_PREFIX format (%s)", ARGV[0]));
    };
    foreach (ethk;ethv;value("/hardware/cards/nic")) {
        if ((exists(ethv['hwaddr']))) {
            hwaddr = ethv['hwaddr'];
            eth = ethk;
            foreach (interk;interv;value("/system/network/interfaces")) {
                if (interk == eth) {
                    if ((exists(interv['ip']))) {
                        mac = opennebula_ipv42mac(ARGV[0], interv['ip']);
                        SELF[eth]['hwaddr'] = mac;
                    }; 
                    if ((exists(interv['bridge'])) &&
                        (exists("/system/network/interfaces/" + interv['bridge'] + "/ip"))) {
                        mac = opennebula_ipv42mac(ARGV[0], 
                              value("/system/network/interfaces/" + interv['bridge'] + "/ip"));
                        SELF[eth]['hwaddr'] = mac;
                    };
                };
            };
        };
    };
    return(SELF);
};
