object template pxelinux_ks_ksdevice_systemd_scheme_3;

include 'pxelinux_ks';

"/system/network/interfaces/{enp2s0}" = value("/system/network/interfaces/{eth0}");

prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "enp2s0";
