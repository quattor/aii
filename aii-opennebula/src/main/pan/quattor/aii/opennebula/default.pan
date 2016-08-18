unique template quattor/aii/opennebula/default;

include 'quattor/aii/opennebula/schema';
include 'quattor/aii/opennebula/functions';

#  null values are set by schema defaults
variable OPENNEBULA_AII_FORCE ?= null; 
variable OPENNEBULA_AII_ONHOLD ?= null;
variable OPENNEBULA_AII_FORCE_REMOVE ?= false;

variable MAC_PREFIX ?= '02:00';

"/system/aii/hooks/configure/" = append(SELF, dict(
    'module', OPENNEBULA_AII_MODULE_NAME,
    "image", OPENNEBULA_AII_FORCE,
    "template", OPENNEBULA_AII_FORCE,
));

bind "/system/aii/hooks" = nlist with validate_aii_opennebula_hooks('configure');

"/system/aii/hooks/install/" = append(SELF, dict(
    'module', OPENNEBULA_AII_MODULE_NAME,
    "vm", OPENNEBULA_AII_FORCE,
    "onhold", OPENNEBULA_AII_ONHOLD,
));

bind "/system/aii/hooks" = nlist with validate_aii_opennebula_hooks('install');

# last is not so important here
"/system/aii/hooks/remove/" = append(SELF, dict(
    'module', OPENNEBULA_AII_MODULE_NAME,
    "image", OPENNEBULA_AII_FORCE_REMOVE,
    "template", OPENNEBULA_AII_FORCE_REMOVE,
    "vm", OPENNEBULA_AII_FORCE_REMOVE,
));

bind "/system/aii/hooks" = nlist with validate_aii_opennebula_hooks('remove');


# Enable ACPI daemon
"/system/aii/hooks/post_reboot/" = append(SELF, dict(
    'module', OPENNEBULA_AII_MODULE_NAME,
));

bind "/system/aii/hooks" = nlist with validate_aii_opennebula_hooks('post_reboot');

# If required replace VM hwaddr using OpenNebula fashion
"/hardware/cards/nic" = if (exists(OPENNEBULA_AII_REPLACE_MAC) && exists(MAC_PREFIX)) {
    opennebula_replace_vm_mac(MAC_PREFIX);
} else {
    SELF;
};
