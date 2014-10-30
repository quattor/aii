unique template quattor/aii/freeipa/schema;

variable FREEIPA_AII_MODULE_NAME = 'freeipa';

## a function to validate all aii_freeipa hooks
## bind "/system/aii/hooks" = nlist with validate_aii_freeipa_hooks('post_reboot')
##

function which_hook_is_next = {
    name = 'which_hook_is_next';
    if (ARGC != 1) {
        error(name+": requires only one argument");
    };
    if (exists(to_string(ARGV[0]))) {
        hooks=value(to_string(ARGV[0]));
        return(length(hooks));
    } else {
        return(0);
    };
};

function validate_aii_freeipa_hooks = {
    name = 'validate_aii_freeipa_hooks';
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
        if (exists(v['module']) && v['module'] == FREEIPA_AII_MODULE_NAME) {
            if (found) {
                error(nam+": second aii_freeipa "+ARGV[0]+" hook found");
            } else {
                found = true;
                ind = i;
            };
        };
    };
    
    if (! found) {
        error(name+": no aii_freeipa "+ARGV[0]+" hook found");
    };
    
    ##
    ## validate the hook
    ## the module name is already validated
    ##
    # TODO implement 

    return(true);
};

type structure_aii_freeipa = {
	"module"   : string with SELF == FREEIPA_AII_MODULE_NAME

    "domain" : type_fqdn # network domain
    "server" : type_hostname # FreeIPA server
    "realm" : string # FreeIPA realm

    "dns" : boolean = false # DNS is controlled by FreeIPA (to register the host ip)
    "disable" : boolean = true # disable the host on AII removal
    "extract_x509" : boolean = false # if true, will extract cert, key and ca files from nssdb
};

