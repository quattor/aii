object template pxelinux_ks_ksdevice_systemd_scheme_4;

include 'pxelinux_ks';

"/system/network/interfaces/{enx78e7d1ea46da}" = value("/system/network/interfaces/{eth0}");

prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "enx78e7d1ea46da";
