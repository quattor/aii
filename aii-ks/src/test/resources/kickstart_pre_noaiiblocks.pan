@{
Profile to verify the kickstart %pre
@}

object template kickstart_pre_noaiiblocks;

include 'kickstart';

include 'blockdevices';

"/system/filesystems/0/aii" = false;
"/system/blockdevices/partitions/sdb1/aii" = false;
