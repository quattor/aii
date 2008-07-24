#
# Linux specific quattor build tools settings
#
# German Cancio <German.Cancio@cern.ch>
#
# $Id$
#

#
# this is also the place to refine between different Linux versions 
# and distributions.
#

#
# in principle, these below are RedHat and RPM specifics.
#
# Take only topdir from rpmmacros. We want everything done in the same place
_rpmbuild  := $(shell [ -x /usr/bin/rpmbuild ] && echo /usr/bin/rpmbuild || echo /bin/rpm)
_topsdir   := rpm-build
ifeq ($(LOCALBUILD),)
	_topdir    := $(shell rpm --eval %_topdir)
else	
	_topsdir   = $(LOCALBUILD)
	_topdir    := $(PWD)/$(_topsdir)
endif
_builddir  := $(_topdir)/BUILD
_specdir   := $(_topdir)/SPECS
_sourcedir := $(_topdir)/SOURCES
_srcrpmdir := $(_topdir)/SRPMS
_rpmdir    := $(_topdir)/RPMS

_rpmver    := $(shell rpm --version | cut -d ' ' -f 3)


###################################################################
# Create linux specific build directories
###################################################################

envdir:: $(_srcrpmdir) $(_rpmdir)
$(_srcrpmdir):
	mkdir -p $(_srcrpmdir)
$(_rpmdir):
	mkdir -p $(_rpmdir)

QTTR_OS=Linux

#
# LSB prefixes
#
QTTR_PREFIX=/usr
# Directory for var files
QTTR_VAR=/var
# Base directory for config files.
QTTR_ETC=/etc
# temporary dir
QTTR_TMP=/tmp
# lock directory
QTTR_LOCKD=$(QTTR_VAR)/lock/quattor
# run directory
QTTR_RUND=$(QTTR_VAR)/run/quattor

# use the system Perl
PERL_EXECUTABLE=/usr/bin/perl

# CGI bin directory
QTTR_CGI_BIN=/var/www/cgi-bin


#
# Derived prefixes
#

# Directory for user binaries.
QTTR_BIN=$(QTTR_PREFIX)/bin

# Directory for system binaries.
QTTR_SBIN=$(QTTR_PREFIX)/sbin

# Directory for support executables
QTTR_LIBEXEC=$(QTTR_PREFIX)/libexec

# Base directory for read-only files.
QTTR_LIB=$(QTTR_PREFIX)/lib

# Base directory for Perl libraries.
QTTR_PERLLIB=$(QTTR_LIB)/perl

# Base directory for Python libraries (TBD!)
QTTR_PYTHLIB=$(QTTR_LIB)/python

# Base directory for man pages.
QTTR_MAN=$(QTTR_PREFIX)/share/man

# Base directory for doc.
QTTR_DOCDIR=$(QTTR_PREFIX)/share/doc

# Base directory for logs
QTTR_LOG=$(QTTR_VAR)/log

# Directory for log rotate files.
QTTR_ROTATED=$(QTTR_ETC)/logrotate.d

# per package documentation
QTTR_DOC=$(QTTR_DOCDIR)/$(NAME)-$(VERSION)

# System directory for startup scripts
QTTR_INITD=/etc/rc.d/init.d

# Copy command
COPY=cp

# Install command
INSTALL=install
