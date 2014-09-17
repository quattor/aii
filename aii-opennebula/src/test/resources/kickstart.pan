object template kickstart;

include 'vm';

prefix "/system/aii/hooks";
"install/0" = nlist(
    "image", true,
    "vm", true,
    "template", true,
    "onhold", true,
);

"remove/0" = nlist(
    "remove", true,
    "image", true,
    "vmtemplate", true,
);
