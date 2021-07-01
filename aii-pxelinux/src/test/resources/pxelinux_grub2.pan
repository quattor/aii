@{
Grub2 object template for aii-pxelinux unit tests.
Only include pxelinux_config.common.pan
}

object template pxelinux_grub2;

include 'pxelinux_config_common';

prefix "/system/aii/nbp/pxelinux";

"kernel" = "(http,myhost.example)/mykernel";
"initrd" = "(http,myhost.example)/path/to/initrd";
