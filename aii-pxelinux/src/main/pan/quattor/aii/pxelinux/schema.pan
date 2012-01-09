# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
unique template quattor/aii/pxelinux/schema;

# PXE configuration.
type structure_pxelinux_pxe_info = {
	"initrd"	: string
	"kernel"	: string
	"ksdevice"	: string with  match (SELF, ("^(eth[0-9]+|link|fd)$")) || is_hwaddr (SELF)
	"kslocation"	: type_absoluteURI
	"label"		: string
	"append"	? string
};

bind "/system/aii/nbp/pxelinux" = structure_pxelinux_pxe_info;
