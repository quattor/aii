object template basic;

include 'vm';

prefix "/system/aii/hooks";
"install/0" = nlist(
    "image", true,
    "vm", true,
    "template", true,
    "onhold", true,
);

"remove/0" = nlist(
    "vm", true,
    "image", true,
    "vmtemplate", true,
);
