unique template quattor/aii/opennebula/default;

include 'quattor/aii/opennebula/schema';

#  undef are set via schema default
variable OPENNEBULA_AII_FORCE ?= undef; 
variable OPENNEBULA_AII_FORCE_REMOVE ?= undef;
variable OPENNEBULA_AII_ONHOLD ?= undef;

"/system/aii/hooks/configure/" = {
    append(nlist(
        'module', OPENNEBULA_AII_MODULE_NAME,

        "image", OPENNEBULA_AII_FORCE,
        "template", OPENNEBULA_AII_FORCE,
        ));

    SELF;
};

bind "/system/aii/hooks" = nlist with validate_aii_opennebula_hooks('configure');

"/system/aii/hooks/install/" = {
    append(nlist(
        'module', OPENNEBULA_AII_MODULE_NAME,

        "vm", OPENNEBULA_AII_FORCE,
        "onhold", OPENNEBULA_AII_ONHOLD,
        ));

    SELF;
};

bind "/system/aii/hooks" = nlist with validate_aii_opennebula_hooks('install');

# last is not so important here
"/system/aii/hooks/remove/" = {
    append(nlist(
        'module', OPENNEBULA_AII_MODULE_NAME,

        "image", OPENNEBULA_AII_FORCE_REMOVE,
        "template", OPENNEBULA_AII_FORCE_REMOVE,
        "vm", OPENNEBULA_AII_FORCE_REMOVE,
        ));

    SELF;
};

bind "/system/aii/hooks" = nlist with validate_aii_opennebula_hooks('remove');


# Enable ACPI daemon
"/system/aii/hooks/post_reboot/" = {
    append(nlist(
        'module', OPENNEBULA_AII_MODULE_NAME
        ));

    SELF;
};

bind "/system/aii/hooks" = nlist with validate_aii_opennebula_hooks('post_reboot');
