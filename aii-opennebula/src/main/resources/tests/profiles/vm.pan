unique template vm;

prefix "/hardware";
"bios" = dict(
    "releasedate", "01/01/2007",
    "version", "0.5.1",
);
"cards" = dict(
    "bmc", list(dict("console", "ttyS0,115200")),
    "nic", dict(
        "eth0", dict("boot", "true", "hwaddr", "AA:00:00:80:01:00", "pxe", "true"),
        "eth1", dict("boot", "false", "hwaddr", "AA:00:00:80:01:01", "pxe", "true"),
        "eth2", dict("boot", "false", "hwaddr", "AA:00:00:80:01:02", "pxe", "true"),
        "eth3", dict("boot", "false", "hwaddr", "AA:00:00:80:01:03", "pxe", "true"),
    ),
    "ib", dict(
        "ib0", dict(
            "media", "infiniband",
            "name", "My fancy Infiniband",
            "pci", dict(
                "vendor", 0x15b3,
                "device", 0x1002,
                "class", 0x0c06,
            ),
        ),
    ),
    "video", dict(
        "video0", dict(
            "media", "Integrated Graphics",
            "name", "Broadwell-U Integrated Graphics",
            "pci", dict(
                "vendor", 0x8086,
                "device", 0x1616,
                "class", 0x0300,
            ),
        ),
    ),
);

"cpu" = list(
    dict(
        "arch", "x86_64",
        "cores", 2,
        "manufacturer", "Intel",
        "model", "Intel(R) Xeon(R) E5520 2.27GHz",
        "speed", 2260,
        "vendor", "Intel",
    ),
    dict(
        "arch", "x86_64",
        "cores", 2,
        "manufacturer", "Intel",
        "model", "Intel(R) Xeon(R) E5520 2.27GHz",
        "speed", 2260,
        "vendor", "Intel",
    )
);
"harddisks" = dict(
    "vda", dict(
        "capacity", 20480,
        "interface", "sas",
        "model", "Generic SAS disk",
        "part_prefix", ""
    ),
    "vdb", dict(
        "capacity", 10480,
        "interface", "sas",
        "model", "Generic SAS disk",
        "part_prefix", ""
    ),
);
"location" = "cubone hyp";
"model" = "KVM Virtual Machine";
"ram" = list (
    dict ("size", 2048,),
    dict ("size", 2048,),
);
"serialnumber" = "kvm/QUATTOR_IMAGE001";

prefix "/system/network";
"default_gateway" = "10.141.10.250";
"domainname" = "cubone.os";
"hostname" = "node630";
"interfaces" = dict(
    "br100", dict(
        "broadcast", "10.141.10.255",
        "delay", 0,
        "ip", "10.141.8.30",
        "linkdelay", 5,
        "netmask", "255.255.0.0",
        "stp", true,
        "type", "Bridge"
    ),
    "br101", dict(
        "broadcast", "172.24.255.255",
        "delay", 0,
        "ip", "172.24.8.30",
        "linkdelay", 5,
        "netmask", "255.255.0.0",
        "stp", true,
        "type", "Bridge"
    ),
    "eth0", dict(
        "bridge", "br100",
        "driver", "bnx2",
        "device", "eth0"
    ),
    "eth1", dict(
        "broadcast", "172.24.255.255",
        "device", "eth1",
        "ip", "172.24.8.30",
        "netmask", "255.255.0.0",
        "driver", "bnx2"
    ),
    "eth2", dict(
        "broadcast", "172.24.255.255",
        "device", "eth2",
        "ip", "172.24.8.31",
        "netmask", "255.255.0.0",
        "driver", "bnx2"
    ),
    "eth3", dict(
        "broadcast", "172.24.255.255",
        "device", "eth3",
        "ip", "172.24.8.32",
        "netmask", "255.255.0.0",
        "driver", "bnx2"
    ),
);

include 'quattor/aii/opennebula/schema';

bind "/system/opennebula" = opennebula_vmtemplate;

prefix "/system/opennebula";
"vnet" = dict(
    "eth0", "br100",
    "eth1", "br101",
    "eth2", "br101",
    "eth3", "br101");

"datastore" = dict(
    "vda", "ceph",
    "vdb", "default");

"graphics" = "SPICE";

"diskcache" = "default";

"ignoremac/interface" = list (
    "eth2",
);

"ignoremac/macaddr" = list (
    "AA:00:00:80:01:03",
);

"permissions/owner" = "lsimngar";
"permissions/group" = "users";
"permissions/mode" = 0400;

"pci" = append(dict(
    "vendor", 0x8086,
    "device", 0x0a0c,
    "class", 0x0403,
));

"labels" = list (
    "quattor",
    "quattor/CE",
);

"placements" = dict (
    "sched_requirements", "CPUSPEED > 1000",
    "sched_rank", "FREE_CPU",
    "sched_ds_requirements", "NAME=GoldenCephDS",
    "sched_ds_rank", "FREE_MB",
);
