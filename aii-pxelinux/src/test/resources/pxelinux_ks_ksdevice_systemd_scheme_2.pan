object template pxelinux_ks_ksdevice_systemd_scheme_2;

include 'pxelinux_ks';

"/system/network/interfaces/{ens1}" = value("/system/network/interfaces/{eth0}");

prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "ens1";
