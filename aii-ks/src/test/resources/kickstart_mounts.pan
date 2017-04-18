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
        "sdb", dict("label", "gpt"),
        escape("mapper/special"), dict("label", "gpt")
    ),
    "partitions", dict(
        "sdb1", dict(
            "holding_dev", "sdb",
            "size", 100,
            "type", "primary", # no defaults !
        ),
        escape("mapper/special1"), dict(
            "holding_dev", escape("mapper/special"),
            "type", "primary",
            "aii", false,
        ),
    ),
    "md", dict(
        "md1", dict (
            "device_list", list ("partitions/sdb1"),
            "raid_level", "RAID0",
            "stripe_size", 64,
            ),
    ),

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
    ),
    dict(
        "mount", true,
        "mountpoint", "/boot",
        "preserve", true,
        "format", false,
        "mountopts", "auto",
        "block_device", "md/md1",
        "type", "ext4",
        "freq", 0,
        "pass", 1
    ),
    dict(
        "mount", true,
        "mountpoint", "/oddfs",
        "preserve", true,
        "format", false,
        "mountopts", "auto",
        "block_device", escape("mapper/special1"),
        "aii", false,
        "type", "ext4",
        "freq", 0,
        "pass", 1
    ),
);
