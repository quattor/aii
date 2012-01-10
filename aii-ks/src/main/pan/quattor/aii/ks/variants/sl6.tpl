################################################################################
# This is 'TPL/sl6.tpl', a aii-ks's file
################################################################################
#
# VERSION:    2.3.0, 24/06/11 17:00
# AUTHOR:     Luis Fernando Muñoz Mejías
# MAINTAINER: Luis Fernando Muñoz Mejías
# LICENSE:    http://cern.ch/eu-datagrid/license.html
#
################################################################################
# Coding style: emulate <TAB> characters with 4 spaces, thanks!
################################################################################

# Template containing OS configuration and default values.

template quattor/aii/ks/variants/sl6;

# Remove deprecated options 
"/system/aii/osinstall/ks/mouse" = null;
"/system/aii/osinstall/ks/langsupport" = null;
"/system/aii/osinstall/ks/packages_args" = list("--ignoremissing");

#add needed packages for @INC at post-install step :
"/system/aii/osinstall/ks/extra_packages" ?= push("perl-CAF", "perl-LC", "perl-AppConfig",);

