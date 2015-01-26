object template aii_vmtemplate;

include 'vm';

# copy for unittests
"/metaconfig/module" = "vmtemplate";
"/metaconfig/contents/system" = value("/system");
"/metaconfig/contents/hardware" = value("/hardware");
