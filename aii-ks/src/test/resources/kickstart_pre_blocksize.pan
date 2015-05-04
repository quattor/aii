@{ 
Profile to verify the kickstart %pre
@}

object template kickstart_pre_blocksize;

include 'kickstart';

include 'blockdevices';

"/system/blockdevices/physical_devs/sdb/correct/size/fraction" = 0.001;
"/system/blockdevices/physical_devs/sdb/correct/size/diff" = 100;

