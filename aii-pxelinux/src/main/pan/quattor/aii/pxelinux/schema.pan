# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

declaration template quattor/aii/pxelinux/schema;

include 'pan/types';

@documentation{
    PXE configuration
}
type structure_pxelinux_pxe_info = {
    "initrd"	: string
    "kernel"	: string
    "ksdevice"  : string with match (SELF, ('^(bootif|link|(eth|seth|em|bond|br|vlan|usb|ib|p\d+p|en(o|(p\d+)?s))\d+(\.\d+)?|enx\p{XDigit}{12})$')) || is_hwaddr (SELF)
    "kslocation"	: type_absoluteURI
    "label"		: string
    "append"	? string
    "rescue"	? string
    "livecd"	? string
    "firmware"	? string
    "setifnames" ? boolean
    "updates" ? type_absoluteURI
};
