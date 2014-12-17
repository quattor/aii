object template aii_imagetemplate;

include 'vm';

# copy for unittests
"/metaconfig/module" = "opennebula/aii_imagetemplate";
"/metaconfig/contents/system" = value("/system");
"/metaconfig/contents/hardware" = value("/hardware");
