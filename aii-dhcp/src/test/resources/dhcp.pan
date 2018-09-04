unique template dhcp;

include "quattor/aii/dhcp/config";

"/system/aii/discovery/dhcp/enabled" = true;

"/hardware/cards/nic/eth0" = dict(
    "boot", true,
);
