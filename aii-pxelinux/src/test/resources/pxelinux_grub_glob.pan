@{
Grub2 object template for aii-pxelinux unit tests.
Only include pxelinux_config.common.pan
}

object template pxelinux_grub_glob;

include 'pxelinux_config_common';

prefix "/system/aii/nbp/pxelinux";
# yeah, just pass non-glob for now
#    get_repos is mocked with simple {} for now
"kernel" = "http://abc.def/mykernel";
"initrd" = "http://abc.def/path/to/initrd";
