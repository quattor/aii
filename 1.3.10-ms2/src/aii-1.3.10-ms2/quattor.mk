###############################################################################
# quattor.mk
###############################################################################
#
# site-specific WP4inst configuration
#
# Common variable definitions. No code here, please!
#
# German Cancio <German.Cancio@cern.ch>
# Marco Emilio Poleggi <Marco.Emilio.Poleggi@cern.ch>
#
# $Id$
###############################################################################
#
# Note. Two classes of variables are considered.
#
#	- "Substitution variables": start with an UPPERCASE ALPHANUMERIC character,
#	  all remaining chracters are UPPERCASE ALPHANUMERIC plus '_' (underscore).
#	  These variables, enclosed in '@' signs, can be referenced inside any 
#	  source files; f.i., defining here
#		FOO = bar
#	  and referencing elsewhere
#		"@FOO@ rules"
#	  produces there
#		"bar rules"
#
#	- "Make variables": all the others, typically lowercase and/or starting 
#	  with an underscore '_', e.g.,
#		_bar = quux
#
###############################################################################

###############################################################################
# General settings
###############################################################################


# default group
GROUP=quattor
# URL
QTTR_URL=http://quattor.org
# default manpage
MANSECT=8
# default license
LICENSE=http://cern.ch/eu-datagrid/license.html
# default vendor
VENDOR=EDG/CERN

TPL_EXT		= .tpl
TPL_CIN_EXT	= $(TPL_EXT).cin


###############################################################################
# Namespace framework
###############################################################################

# templates package root
PAN_TEMPLATESDIR	= $(QTTR_DOCDIR)/pan-templates

# installation (sub)directories for packaging
PAN_NAMESPACE_SDIR	= namespaces
PAN_STD_NS_SDIR	= standard
PAN_EXM_NS_SDIR	= examples

# these are namespace subdirectories relative to 
# $(PAN_TEMPLATESDIR)/$(PAN_NAMESPACE_SDIR)
PAN_CLSTR_NS		= clusters
PAN_COMP_NS			= components
PAN_HW_NS			= hardware
PAN_HW_CPU_NS		= $(PAN_HW_NS)/cpu
PAN_HW_CARD_NS		= $(PAN_HW_NS)/card
PAN_HW_DISK_NS		= $(PAN_HW_NS)/disk
PAN_HW_MACHN_NS		= $(PAN_HW_NS)/machines
PAN_HW_NIC_NS		= $(PAN_HW_CARD_NS)/nic
PAN_HW_RAM_NS		= $(PAN_HW_NS)/ram
PAN_MYCLST_NS		= $(PAN_CLSTR_NS)/mycluster
PAN_OS_NS			= os
PAN_PAN_NS			= pan
PAN_QTTR_FUNCT_NS	= $(PAN_QUATTOR_NS)/functions
# this is not a namespace, just a directory
PAN_PROFILES_NS		= profiles
PAN_QUATTOR_NS		= quattor
PAN_REPO_NS			= repository
PAN_RPMS_NS			= $(PAN_OS_NS)/i386_sl3/rpms
PAN_SITE_NS			= site


# In view of enhancements for relocatability, this should become
# the base location for any configuration file, with a subdirectory
# structure for different services
QTTR_ETC_CONFDIR=$(QTTR_ETC)/quattor

# common extension for configuration files
QTTR_CFG_EXT=conf


###############################################################################
# CDB settings
###############################################################################

QTTR_PERLLIB_CDB=$(QTTR_PERLLIB)/CDB
QTTR_PERLLIB_CDB_SECURITY=$(QTTR_PERLLIB_CDB)/Security

QTTR_CDB_LIB=/var/lib/cdb


###############################################################################
# NCM settings
###############################################################################

# Base dir for NCM files.
NCM_LIB=$(QTTR_LIB)/ncm

# Directory for templates and other fixed configuration files.
# Files are normally prefixed with the module name, or
# stored in subdirectories with the same name as the module.
NCM_DATA=$(NCM_LIB)/config

# Same but for components defined in XML profile.
NCM_DATA_VAR=$(QTTR_VAR)/ncm/config

# Directory for components (.pm files)
NCM_COMP=$(QTTR_PERLLIB)/NCM/Component

# Directory for components (.pm files) defined in XML profile.
NCM_COMP_VAR=$(QTTR_VAR)/ncm/lib/perl/NCM/Component

# Directory for log files.
NCM_LOG=$(QTTR_LOG)/ncm

# Directory for lock files.
NCM_LOCK=$(QTTR_LOCKD)/ncm

# Directory for temporary files (may be deleted when objects are
# not running).
# Files are normally prefixed with the module name, or
# stored in subdirectories with the same name as the module.
# Components should not store temporary files in system tmp directories.
NCM_COMP_TMP=$(QTTR_VAR)/ncm/tmp

# default component manual page
NCM_MANSECT=8

# For components only:

# extra RPM 'requires' header to insert
NCM_EXTRA_REQUIRES=

# directory for auxiliary data files
NCM_DATA_COMP=$(NCM_DATA)/$(COMP)/

# directory for template files
NCM_DATA_COMP_VAR=$(NCM_DATA_VAR)/$(COMP)/

# directory for NCM template files
NCM_TPL_FILES=$(PAN_TEMPLATESDIR)/$(PAN_NAMESPACE_SDIR)/$(PAN_COMP_NS)/


###############################################################################
# Security settings
###############################################################################

# user certificate defaults
DFLT_X509_UCERT=.globus/usercert.pem
DFLT_X509_UKEY=.globus/userkey.pem

# configuration directory
QTTR_ETC_SECURITY=$(QTTR_ETC_CONFDIR)/security


###############################################################################
# Metadata settings
###############################################################################

# this should be multiline (support still missing)
_OPT_CFG_TAGS	:= NOTES

# mandatory tags to be checked in config.mk
_MND_CFG_TAGS	:= AUTHOR COMP DESCR MAINTAINER NAME VERSION

# mandatory tags to be checked in source files
_MND_SRC_TAGS	:= AUTHOR MAINTAINER VERSION

# fine in most cases unless C-ish code is out there
_CMNT_MARK   	:= "\#"

# mandatory header for all source files.
_HEADER_TAGS	:= $(_MND_SRC_TAGS) LICENSE
# check only the first comment lines
_CNTXT_LINES	:= 12
_MND_SRC_HEADER	:= src-header.txt


###############################################################################
# Files
###############################################################################

_DOC_FILES		:= LICENSE ChangeLog README
_BLD_FILES		:= config.mk
# mandatory files to be checked when committing CVS (not enforced yet)
_MND_CVS_FILES	:= $(_DOC_FILES) $(_BLD_FILES)
# these depend on the specific case
_SRC_FILES		:= 
# deprecated files to be checked when committing CVS (not enforced yet)
_DPR_CVS_FILES	:= MAINTAINER
# files to be checked for deprecated things
_DIRTY_TPL_FILES:=


###############################################################################
# templates clean-up
###############################################################################

# keywords to be removed
_TPL_THINGS_TO_DEL  := '^\s*define\s+'
# keywords to be commented
_TPL_THINGS_TO_COM  := 'descro\s+' 'description\s+"'
# keywords to be substituted
_TPL_THINGS_TO_SUB  := '\s*=\s*default\s*\((.+?)\)/ ?= \1'
# for double checking (some deprecated patterns could span over more lines)
_TPL_DPRCTD_THINGS  := $(_things_to_del) $(_things_to_com) 'default\s*\('

