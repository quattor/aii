declaration template quattor/aii/opennebula/schema;

variable OPENNEBULA_AII_MODULE_NAME = 'opennebula';

## a function to validate all aii_opennebula hooks

function validate_aii_opennebula_hooks = {
    name = 'validate_aii_opennebula_hooks';
    if (ARGC != 1) {
        error(name+": requires only one argument");
    };
    
    if (! exists(SELF[ARGV[0]])) {
        error(name+": no "+ARGV[0]+" hook found.");
    };
   
    
    l = SELF[ARGV[0]];
    found = false;
    ind = 0;
    foreach(i;v;l) {
        if (exists(v['module']) && v['module'] == OPENNEBULA_AII_MODULE_NAME) {
            if (found) {
                error(nam+": second aii_opennebula "+ARGV[0]+" hook found");
            } else {
                found = true;
                ind = i;
            };
        };
    };
    
    if (! found) {
        error(name+": no aii_opennebula "+ARGV[0]+" hook found");
    };
    
    if (ind != length(l) -1) {
        error(format("%s: aii_opennebula %s hook has to be last hook (idx %s of %s)", name, ARGV[0], ind, length(l)));
    };
    
    ## validate the hook
    return(true);
};

type structure_aii_opennebula = {
    "module" : string with SELF == OPENNEBULA_AII_MODULE_NAME
    "image" : boolean = false # force create image [implies on remove remove image (also stop/delete vm) ]
    "template" : boolean = false # force (re)create template [implies on remove remove template (also stop/delete vm) ]
    "vm" : boolean = false # instantiate template (i.e. make vm)
    "onhold" : boolean = true # when template is instantiated, then vm is placed onhold [if false, will start the VM asap]
    "remove" : boolean = true # remove all VM resources
};

type opennebula_vmtemplate_vnet = string{} with {
    # check if all entries in the map have a network interface
    foreach (k;v;SELF) {
        if (! exists("/system/network/interfaces/"+k)) {
            return(false);
        };
    };
    # check if all interfaces have an entry in the map
    foreach (k;v;value("/system/network/interfaces")) {
        if ((! exists(SELF[k])) && 
            (! exists(v['type']) || # if type is missing, it's a regular ethernet interface
             (! match('^(Bridge|OVSBridge)$', v['type'])) # these special types are OK 
             )
            ) {
            return(false);
        };
    };
    return(true);
};

type opennebula_vmtemplate_datastore = string{} with {
    # check is all entries in the map have a hardrive
    foreach (k;v;SELF) {
        if (! exists("/hardware/harddisks/"+k)) {
            return(false);
        };
    };
    # check if all interfaces have an entry in the map
    foreach (k;v;value("/hardware/harddisks")) {
        if (! exists(SELF[k])) {
            return(false);
        };
    };
    return(true);
};

type opennebula_vmtemplate = {
    "vnet" : opennebula_vmtemplate_vnet
    "datastore" : opennebula_vmtemplate_datastore
};
