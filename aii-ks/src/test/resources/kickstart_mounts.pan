@{ 
Profile to ensure that the kickstart mountpoints are generated 
@}
object template kickstart_mounts;

include 'kickstart';

prefix "/system/aii/osinstall/ks";
"version" = "19.31";


"/hardware/harddisks/sdb" = dict(
    "capacity", 4000,
);

"/system/blockdevices" = dict(
    "physical_devs", dict(
        "sdb", dict("label", "gpt")
     ),
    "partitions", dict(
        "sdb1", dict(
            "holding_dev", "sdb",
            "size", 100,
            "type", "primary", # no defaults !
        ),
    )
);

"/system/filesystems" = list (
    dict(
        "mount", true,
        "mountpoint", "swap",
        "preserve", true,
        "format", false,
        "mountopts", "auto",
        "block_device", "partitions/sdb1",
        "type", "swap",
        "freq", 0,
        "pass", 1
    )
);
