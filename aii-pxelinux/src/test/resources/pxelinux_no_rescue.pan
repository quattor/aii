@{
Remove rescue, livecd and firmware config from base profile
}

object template pxelinux_no_rescue;

include 'pxelinux_config_common';

prefix '/system/aii/nbp/pxelinux';
'firmware' = null;
'livecd' = null;
'rescue' = null;
