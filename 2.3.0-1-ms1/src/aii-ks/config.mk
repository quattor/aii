COMP=ks
NAME=aii-$(COMP)
AUTHOR=Luis Fernando Muñoz Mejías
MAINTAINER=Luis Fernando Muñoz Mejías
DESCRIPTION=AII plug-in that generates Kickstart files.
DESCR=$(DESCRIPTION)
VERSION=1.1.16
RELEASE=1
PAN_PATH_DEV=/system/blockdevices/
PAN_PATH_FS=/system/filesystems/
PACKAGE_PATH=NCM
NCM_EXTRA_REQUIRES=ncm-lib-blockdevices >= 0.15 aii-server >= 0.99 pan-templates > 3.0.7
DATE=03/07/08 20:35
