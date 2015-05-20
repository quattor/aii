# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
unique template quattor/aii/pxelinux/schema;

# PXE configuration.
type structure_pxelinux_pxe_info = {
    "initrd"	: string
    "kernel"	: string
    "ksdevice"	: string with match (SELF, ("^(eth[0-9]+|link|p[0-9]+p[0-9]+|fd|em[0-9]+|bootif)$")) || is_hwaddr (SELF)
    "kslocation"	: type_absoluteURI
    "label"		: string
    "append"	? string
    "rescue"	? string
    "livecd"	? string
    "firmware"	? string
    "setifnames" ? boolean
    "updates" ? type_absoluteURI
};

bind "/system/aii/nbp/pxelinux" = structure_pxelinux_pxe_info;
