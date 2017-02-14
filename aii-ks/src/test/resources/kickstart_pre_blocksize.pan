@{ 
Profile to verify the kickstart %pre
@}

object template kickstart_pre_blocksize;

include 'kickstart';

include 'blockdevices';

"/system/blockdevices/physical_devs/sdb/validate/size/fraction" = 0.001;
"/system/blockdevices/physical_devs/sdb/validate/size/diff" = 100;

