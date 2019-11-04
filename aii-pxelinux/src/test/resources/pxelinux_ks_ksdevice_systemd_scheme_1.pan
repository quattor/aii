object template pxelinux_ks_ksdevice_systemd_scheme_1;

include 'pxelinux_ks';

"/system/network/interfaces/{eno1}" = value("/system/network/interfaces/{eth0}");

prefix "/system/aii/nbp/pxelinux";
"ksdevice" = "eno1";
