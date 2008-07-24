###############################################################################
# quattor-buildtools.mk
###############################################################################
#
# Common Makefile for building quattor software
# Based on the EDG adapted DICE build tools
#
# German Cancio <German.Cancio@cern.ch>
# Marco Emilio Poleggi <Marco.Emilio.Poleggi@cern.ch>
#
# $Id$
###############################################################################

.PHONY: release minorversion majorversion tagversion pack rpm pkg prep clean\
	 dist userdoc apidoc check test checkmndfiles checkcfgtags checkdprfiles\
	 checksrctags header help tagstable markobsolete

help:
	@echo "usage: make target [target...]";\
	echo "most frequently used targets:";\
	echo "  check        -- check for: ";\
	echo "                  * 'obsolete' mark in config.mk";\
	echo "                  * mandatory files (defined in 'quattor.mk')";\
	echo "                  * deprecated files (defined in 'quattor.mk')";\
	echo "                  * mandatory comments in source files (needs _SRC_FILES to be defined)";\
	echo "                  * mandatory meta tags in 'config.mk'";\
	echo "                  * deprecated patterns in Pan template files - mainly for NCM components";\
	echo "                    (needs _DIRTY_TPL_FILES to be defined)";\
	echo "  clean        -- remove backup files and other garbage";\
	echo "  dist         --> pack ";\
	echo "  header       -- add a header to all source files (needs _SRC_FILES to be defined)";\
	echo "  majorversion -- increase version X+1.y.z, commit and tag in CVS";\
	echo "  markobsolete -- add to config.mk an 'OBSOLETE' mark and commit in CVS (no tag is added)";\
	echo "  minorversion -- increase version x.Y+1.z, commit and tag in CVS";\
	echo "  pack         -- build a tar.gz package for distribution";\
	echo "  release      -- increase version x.y.Z+1, commit and tag in CVS";\
	echo "  rpm          -- build an RPM  package for distribution";\
	echo "  tagstable    -- tag in CVS the HEAD revision with 'STABLE' (move tag!)";\
	echo "  test         -- run the tests, if any, coming with the module";\
	echo "[Un]complete documentation at <https://twiki.cern.ch/twiki/bin/view/ELFms/QuattorBuildFramework>"


###############################################################################
# GLOBALS
###############################################################################

_quattor_mk   := $(shell ls $(BTDIR)/quattor.mk 2>/dev/null || echo quattor.mk)
_test_mk   := $(shell ls $(BTDIR)/quattor-test.mk 2>/dev/null || echo quattor-test.mk)

_os        := $(shell uname -s)

_quattor_mk_os := $(shell ls $(BTDIR)/quattor-$(_os).mk 2>/dev/null || echo quattor-$(_os).mk)

_date      := $(shell date '+%d/%m/%y %H:%M')

include    $(_quattor_mk_os)
include	   $(_quattor_mk)
include    config.mk
include	   $(_test_mk)

_module    = $(NAME)
_vpfx      = $(NAME)_
_vtag      = $(subst -,_,$(subst .,_,$(_vpfx)$(VERSION)$(BRANCH)))
_prodname  = $(NAME)-$(VERSION)$(BRANCH)
_prodtar   = $(_prodname).src.tgz
_podopt     = "--release=Release: $(VERSION)" \
             --center=$(GROUP) "--date=$(DATE)"


###############################################################################
# Create build directories
###############################################################################

envdir:: $(_builddir) $(_specdir) $(_sourcedir)
$(_builddir):
	mkdir -p $(_builddir)
$(_specdir):
	mkdir -p $(_specdir)
$(_sourcedir):
	mkdir -p $(_sourcedir)


###############################################################################
# Create new release/version/majorversion
###############################################################################
#
# These targets update the X.Y.Z components of the version in the
# config file and then commit the current version, tagging all
# files with the release number from the config file. Also
# wires the current date and time into the config file. Also
# adds an entry to the ChangeLog.


release: config.tmp
	@echo '[INFO] increasing release number x.x.<X> and timestamp..'
	@perl <config.tmp >config.mk -e 'while (<>) \
	  { s/^(VERSION=\d+\.\d+\.)(\d+)(.*)$$/$$1.($$2+1).$$3/e; \
	    s/^(RELEASE=)(\d+)(.*)$$/$$1."1".$$3/e; print; }'
	@$(MAKE) tagversion

minorversion: config.tmp
	@echo '[INFO] increasing minorversion number x.<X>.x and timestamp..'
	@perl <config.tmp >config.mk -e 'while (<>) \
	  { s/^(VERSION=\d+\.)(\d+)(\..*)$$/$$1.($$2+1).".0"/e; \
	    s/^(RELEASE=)(\d+)(.*)$$/$$1."1".$$3/e; print; }'
	@$(MAKE) tagversion

majorversion: config.tmp
	@echo '[INFO] increasing majorversion number <X>.x.x and timestamp..'
	@perl <config.tmp >config.mk -e 'while (<>) \
	  { s/^(VERSION=)(\d+)(\..*)$$/$$1.($$2+1).".0.0"/e; \
	    s/^(RELEASE=)(\d+)(.*)$$/$$1."1".$$3/e; print; }'
	@$(MAKE) tagversion

config.tmp: config.mk
	@cvs update .
	@sed <config.mk >config.tmp '/^DATE=/d'
	@echo 'DATE=$(_date)' >>config.tmp
	@cp config.mk config.mk~

# tags are always moved, i.e. no complaint if they already exist
tagversion:
	@echo "[INFO] cvs committing new release: $(VERSION)"
	@rm -f config.tmp
	@perl -e '$$date=`date +%Y-%m-%d`; \
		chomp($$date); \
		$$login=getlogin(); \
		$$logstr="<unknown>"; \
		$$logstr=(getpwnam($$login))[6] if defined $$login; \
		print $$date."  $$logstr\n\n"; \
		print "\t* Release: $(VERSION)\n";' >ChangeLog.tmp
	@if [ "$(EDITOR)" -a -x "$(EDITOR)" ]; then \
		perl -e 'print "\t- [your comment here]"' >>ChangeLog.tmp; \
		$(EDITOR) ChangeLog.tmp; \
		perl -e '$$/=undef; $$text=<>; $$text =~ s/\s*\n*$$//s; \
		print "$$text\n\n"' < ChangeLog.tmp > ChangeLog.tmp2; \
		mv ChangeLog.tmp2 ChangeLog.tmp; \
	else \
		echo "[INFO] Enter ChangeLog comment (hit CTRL+D to stop):"; \
		perl -e '$$text=""; while(<>) { $$text .= "\t$$_" }; \
		$$text =~ s/^\s*(.+?)\s*\n*$$/$$1/s; \
		chomp($$text); print "\t- $$text\n\n"' >>ChangeLog.tmp; \
	fi
	@if [ ! -r ChangeLog ] ; then touch ChangeLog ; cvs add ChangeLog ; fi
	@cp ChangeLog.tmp /tmp/ChangeLog.tmp.$$$
	@cat ChangeLog >>ChangeLog.tmp
	@mv ChangeLog.tmp ChangeLog
	@cvs commit -F /tmp/ChangeLog.tmp.$$$ 
	@rm -f /tmp/ChangeLog.tmp.$$$
	@echo "[INFO] cvs tagging new release: $(VERSION)"
	@cvs tag -F -c `echo $(_vtag) |sed -e s/\\\./_/g -e s/-/_/g`
	@cvs tag -F -c latest
	@$(MAKE) tagstable

tagstable:
	@echo "[INFO] cvs tagging STABLE release"
	@ prompt='Do you want to tag this release as STABLE? [no]: ';\
	while read -p "$$prompt" ans || exit 1; do\
		[ -z $$ans ] && ans='no';\
		case $$ans in\
			[Yy]|[Yy]es)\
				cvs tag -F -c STABLE;\
				break;\
				;;\
			[Nn]|[Nn]o)\
				break;\
				;;\
			*)\
				prompt='Answer either "yes" or not at all: ';\
		esac\
	done

# mark as OBSOLETE (no CVS tag is added). A message to be added to config.mk 
# can be passed through the variable OBSOLETE_MSG
markobsolete:
	@echo "[INFO] marking as OBSOLETE"
	@obs_msg='1';\
	if [ ! -z "$$OBSOLETE_MSG" ]; then\
		obs_msg="$$OBSOLETE_MSG";\
	fi;\
	if [ ! -w config.mk ]; then\
		echo "[ERROR] config.mk: file missing or not writable" >&2;\
		exit 1;\
	fi;\
	if [ "`sed -nr '/^\s*OBSOLETE/ p' config.mk`" ]; then\
		echo "[ERROR] already marked as OBSOLETE" >&2;\
		exit 1;\
	fi;\
	echo OBSOLETE="$$obs_msg" >> config.mk
	@cvs commit -m 'Module marked as OBSOLETE'


###############################################################################
# Build distributions in tar & RPM/PKG format
###############################################################################
#
# These targets make distribution tar files and PKGs/RPMs from the
# CVS repository, using the version declared in the config file.
# The checked-out files in the current directory are neither
# modified, nor read (apart from the config file).
#
# "pack" and "rpm" built from the sources in the current directory.
#
#
# The prep:: target allows the including makefile to specify actions
# required to process the files at distribution pack time.
#
# These targets make distribution tar files and PKGs/RPMs based on the 
# checked-out sources in the current directory. No connection to
# the CVS repository is required, and the files do not need to be
# committed. The RPM version numbers are generated from the
# version number specified in the config file.
#

pack:	checkobsolete envdir
	@echo "[INFO] packing distribution..."
	@rm -rf $(_builddir)/$(_prodname)
	@rm -f $(_sourcedir)/$(_prodtar)
	@mkdir -p $(_builddir)/$(_prodname)
	@find . -path '*CVS*' -prune -o -type f -print >files.tmp
	@tar cfT - files.tmp |(cd $(_builddir)/$(_prodname) ; tar xf -)
	@rm -f files.tmp
	@[ ! -f quattor-buildtools.mk -a -f $(BTDIR)/quattor-buildtools.mk ] \
	     && cp $(BTDIR)/quattor-buildtools.mk $(_builddir)/$(_prodname) \
             || : ;
	@[ ! -f quattor-component.mk -a -f $(BTDIR)/quattor-component.mk ] \
	     && cp $(BTDIR)/quattor-component.mk $(_builddir)/$(_prodname) \
             || : ;
	@[ ! -f quattor.mk -a -f $(_quattor_mk) ] \
	      && cp $(_quattor_mk) $(_builddir)/$(_prodname) \
	     || : ;
	@[ ! -f quattor-$(_os).mk -a -f $(_quattor_mk_os) ] \
	      && cp $(_quattor_mk_os) $(_builddir)/$(_prodname) \
	     || : ;
	@[ ! -f quattor-test.mk -a -f $(_test_mk) ] \
	      && cp $(_test_mk) $(_builddir)/$(_prodname) \
	     || : ;
	@[ ! -f specfile.spec -a -f $(BTDIR)/component-specfile ] \
	     && cp $(BTDIR)/component-specfile \
		$(_builddir)/$(_prodname)/specfile.spec \
             || : ;
	@cd $(_builddir)/$(_prodname) ; \
	    sed <config.mk >config.tmp \
                -e 's%^RELEASE=\(.*\)%RELEASE=\1%' \
                -e 's%^VERSION=.*%&$(BRANCH)%' ; \
	    mv config.tmp config.mk ; \
	    echo  >>config.mk ; \
	    echo 'TARFILE=$(_prodtar)' >>config.mk ; \
	    echo 'PROD=\#' >>config.mk ; \
	    $(MAKE) config.sh ;\
	    $(MAKE) prep ;\
            test -n "$(_test_dep)" && rm -f $(_test_dep) ;\
	    rm -f config.sh
	@cd $(_builddir) ; tar czf $(_sourcedir)/$(_prodtar) $(_prodname)


spec: pack
	@echo [INFO] generating specfile.spec...
	@cd $(_builddir)/$(_prodname) ; \
	    $(MAKE) config.sh ;\
	    ./config.sh <specfile.spec >$(_specdir)/$(_prodname).spec
	@test -f ChangeLog && \
	    $(BTDIR)/cl2rpm ChangeLog \
	                        >>$(_specdir)/$(_prodname).spec || true
rpm:	spec
	@echo [INFO] building rpm...
	@cd $(_specdir) ; $(_rpmbuild) \
		--define '_topdir $(_topdir)' \
		--define '_specdir $(_specdir)' \
		--define '_sourcedir $(_sourcedir)' \
		--define '_srcrpmdir $(_srcrpmdir)' \
		--define '_rpmdir $(_rpmdir)' \
		-ba $(_specdir)/$(_prodname).spec

pkg:    spec
	@echo [INFO] building pkg...
	@cd $(_specdir) ; $(_pkgbuild) -f $(_specdir)/$(_prodname).spec

prep::

###############################################################################
# Create substitution script
###############################################################################
#
# This target reads the config file and creates a shell script which
# can substitute variables of the form @VAR@ for all config
# variables VAR. The messing around with the temporary makefile is
# to ensure that any recursive or external references in the
# variable values are evaluated by "make" in the same context as
# when the config file is included in the makefile.

config.sh: Makefile $(_test_dep)
	@cp /dev/null makefile.tmp
	@echo "BTDIR:=$(BDTDIR)" >>makefile.tmp
	@echo include $(_quattor_mk_os) >>makefile.tmp
	@echo include $(_quattor_mk) >>makefile.tmp
	@echo include config.mk >>makefile.tmp
	@echo include $(_test_mk) >>makefile.tmp
	@echo dumpvars: >>makefile.tmp
	@cat $(_quattor_mk_os) $(_quattor_mk) config.mk $(_test_mk) | \
		perl >>makefile.tmp -e 'my $$fmt = "\t\@echo \"-e \\\"s\@%s\@\$$(%s)g\\\" \\\\\""; while (<>) { $$v{$$1}=1 if /^([0-9A-Z][0-9A-Z_]+)\s*:?=.*$$/; } map { printf "$$fmt >>config.sh\n", $$_, $$_; } sort(keys(%v)); print "\n";'
	@echo '#!/bin/sh' >config.sh
	@echo 'sed \' >>config.sh
	@$(MAKE) -f makefile.tmp dumpvars >/dev/null
	@echo '-e "s/\@MSG\@/ ** Generated file : do not edit **/"'>>config.sh 
	@chmod oug+x config.sh
	@rm makefile.tmp

# Would like to add the following, but unfortunately gsed on 
# solaris is too old to have the correct option. 
# Try to do this some other way...
#	@echo '-e "s/%%\(.*\)%%/cat \1/e"'>>config.sh


###############################################################################
# Configure
###############################################################################

%:: %.cin config.sh
	@echo [INFO] configuring $@...
	@rm -f $@ ; cp $< $@
	@./config.sh <$< >$@ ; chmod oug-w $@
	@sed -i -r 's@SELF@$@g' $@

ncm-%.$(MANSECT):: %.pod
	@echo [INFO] creating $@...
	@pod2man $(_podopt) $< >$@

%.$(MANSECT):: %.pod
	@echo [INFO] creating $@...
	@pod2man $(_podopt) $< >$@

ncm-%.html:: %.pod
	@echo [INFO] creating $@...
	@pod2html $< >$@

###############################################################################

clean::
	@echo [INFO] cleaning common files...
	@rm -f config.sh config.tex
	@rm -f `find . -name '*~'`
	@rm -f `find . -name '*#'` 
	@rm -f `find . -name '*.tmp'`
	@rm -rf $(_topsdir)


###############################################################################
# dummy EDG targets
###############################################################################

userdoc:
	@echo '[INFO] user documentation included in distribution'
apidoc:
	@echo '[INFO] API documentation included in distribution' >&2

dist:	pack


###############################################################################
# test targets
###############################################################################

test: $(_quattor_testdir)/*
	@echo [INFO] running tests ...
	@cd $(_quattor_testdir);\
	if [ -x $(_quattor_testharn) ]; then\
		./$(_quattor_testharn) || exit 1;\
	else\
		echo "[ERROR] Test harness not found or not executable" >&2;\
		exit 1;\
	fi


###############################################################################
# check
###############################################################################

# check if the module is obsolete. The variable OBSOLETE is defined in 
# config.mk. This check only warns if the module is obsolete and CHKOBS_OK is 
# defined
checkobsolete: config.mk
	@echo "[INFO] Checking if module is obsolete...";\
	obs_msg=`sed -nr 's/^\s*OBSOLETE\s*=\s*(.+)$$/\1/ p' config.mk`;\
	if [ ! -z "$$obs_msg" ]; then\
		if [ `echo $$obs_msg | sed -nr '/^ncm-\w+$$/ p'` ]; then\
			obs_msg=": obsoleted by $$obs_msg";\
		elif [ "$$obs_msg" != '1' ]; then\
			obs_msg=": $$obs_msg";\
		else\
			obs_msg=;\
		fi;\
		if [ -z $$CHKOBS_OK ]; then\
			echo "[ERROR] module is OBSOLETE"$$obs_msg >&2;\
			exit 1;\
		else\
			echo "[WARN] module is OBSOLETE"$$obs_msg >&2;\
		fi;\
	fi

# check for mandatory files
checkmndfiles: $(_MND_CVS_FILES)
	@echo "[INFO] Checking mandatory files...";\
	error=0;\
	for i in $(_MND_CVS_FILES); do\
        if [ ! -f $$i -o ! -s $$i ]; then\
            echo "[ERROR] $$i: mandatory file missing or empty" >&2;\
            error=1;\
        fi;\
    done;\
	exit $$error

# check for deprecated files.
# MAINTANER file is removed iff the corresponding tag is found in config.mk
# No prerequisites stated, since the files might not exist (correct!)
checkdprfiles:
	@echo "[INFO] Checking deprecated files...";\
	error=0;\
	for i in $(_DPR_CVS_FILES); do\
        if [ -f $$i ]; then\
            echo "[INFO] $$i: deprecated; removing...";\
			if [ $$i = 'MAINTAINER' ]; then\
				tag=MAINTAINER;\
				if [ -f config.mk -a -z "`sed -nr "/^\s*$$tag\s*=.+$$/ =" config.mk`" ]; then\
           			echo "[ERROR] config.mk: file missing or tag 'MAINTAINER' missing or incomplete" >&2;\
					error=1;\
					continue;\
				fi;\
			fi;\
			rm -f $$i;\
			cvs remove $$i || error=1;\
        fi;\
    done;\
	exit $$error

# check for mandatory meta tags in config.mk
checkcfgtags: config.mk
	@echo "[INFO] Checking config.mk tags...";\
    error=0;\
    for tag in $(_MND_CFG_TAGS); do\
    	if [ -z "`sed -nr "/^\s*$$tag\s*=.+$$/ =" config.mk`" ]; then\
           echo "[ERROR] config.mk: mandatory tag '$$tag' missing or incomplete" >&2;\
           error=1;\
        fi;\
    done;\
    exit $$error

# check for mandatory comments in source files
checksrctags: $(_SRC_FILES)
	@echo "[INFO] Checking source files tags...";\
	error=0;\
	for file in $(_SRC_FILES); do\
        for tag in $(_MND_SRC_TAGS); do\
            if [ -z `sed -nr "/^\s*$(_CMNT_MARK)+\s*$$tag\s*:\s*@$$tag@\s*.*$$/ =" $$file` ]; then\
                echo "[ERROR] $$file: mandatory comment line '$(_CMNT_MARK) $$tag: @$$tag@' missing or incomplete" >&2;\
                error=1;\
            fi;\
        done;\
    done;\
    exit $$error

# check for deprecated patterns in template files (mainly used for double checks)
# will WARN only
checkdprwords:	$(_DIRTY_TPL_FILES)
	@echo "[INFO] Checking deprecated words in templates...";\
	for s in $(_TPL_DPRCTD_THINGS); do\
		for i in $(_DIRTY_TPL_FILES); do\
			if [ "`sed -nr "/$$s/ =" $$i`" ]; then\
				echo "[WARN] $$i: deprecated pattern '$$s' found" >&2;\
			fi;\
		done;\
	done

check: checkobsolete checkmndfiles checkcfgtags checkdprfiles checksrctags checkdprwords


###############################################################################
# to remove/comment/substitute deprecated words
###############################################################################
tplclean: $(_DIRTY_TPL_FILES)
	@echo "[INFO] Cleaning deprecated words in templates...";\
	big_del_regex='';\
	for s in $(_TPL_THINGS_TO_DEL); do\
		big_del_regex=$$big_del_regex"|($$s)";\
	done;\
	big_com_regex='';\
	for s in $(_TPL_THINGS_TO_COM); do\
		big_com_regex=$$big_com_regex"|($$s)";\
	done;\
	big_del_regex=`echo $$big_del_regex | sed -r 's/^\|//'`;\
	big_com_regex=`echo $$big_com_regex | sed -r 's/^\|//'`;\
	if [ "$$big_del_regex" -o "$$big_com_regex" -o "$(_TPL_THINGS_TO_SUB)" ]; then\
		for i in $(_DIRTY_TPL_FILES); do\
			cp --backup=numbered  $$i $$i.bak;\
		done;\
		[ "$$big_del_regex" ] && for i in $(_DIRTY_TPL_FILES); do\
			sed -i -r "s/$$big_del_regex//g" $$i;\
		done;\
		[ "$$big_com_regex" ] && for i in $(_DIRTY_TPL_FILES); do\
			sed -i -r "s/$$big_com_regex/# /g" $$i;\
		done;\
		for sub in $(_TPL_THINGS_TO_SUB); do\
			for i in $(_DIRTY_TPL_FILES); do\
				sed -i -r "s/$$sub/g" $$i;\
			done;\
		done;\
	fi


###############################################################################
# header
###############################################################################
# Add a header to all source files. Handle duplicated information as much as
# possible, looking at the first _CNTXT_LINES lines only
_tmp_file		:= .$(NAME).tmp
_tmp_hdr_orig	:= .$(NAME).orig.tmp
_tmp_hdr_file	:= .$(NAME).hdr.tmp
_src_hdr_file	:= $(BTDIR)/$(_MND_SRC_HEADER)
header: $(_SRC_FILES)
	@echo "[INFO] Adding header to source files...";\
	for file in $(_SRC_FILES); do\
		sed -r "s/^/$(_CMNT_MARK)/" $(_src_hdr_file) > $(_tmp_hdr_file) || exit 1;\
		rm -f $(_tmp_file);\
		cp $$file $$file.bak;\
		sed -i -r -e '/^#!/ { w $(_tmp_file)' -e 'd }' $$file || exit 1;\
		head -n$(_CNTXT_LINES) $$file > $(_tmp_hdr_orig);\
		if diff $(_tmp_hdr_file) $(_tmp_hdr_orig) >/dev/null; then\
			mv $$file.bak $$file;\
			rm -f $(_tmp_file) $(_tmp_hdr_orig) $(_tmp_hdr_file);\
			continue;\
		fi;\
		sed -i -r '1,$(_CNTXT_LINES) d' $$file || exit 1;\
		for tag in $(_HEADER_TAGS) RESPONSIBLE; do\
			sed -i -r "/^\s*$(_CMNT_MARK)+\s*\w*\s*@?$$tag@?\s*:?.*$$/ d" $(_tmp_hdr_orig) || exit 1;\
		done;\
		if [ "`echo $$file | sed -nr '/\.pod\.?\w*$$/ p'`" ]; then\
			echo >> $(_tmp_hdr_file);\
		fi;\
		cat $(_tmp_hdr_file) $(_tmp_hdr_orig) $$file >> $(_tmp_file);\
		mv $(_tmp_file) $$file;\
		rm -f $(_tmp_hdr_orig) $(_tmp_hdr_file);\
		echo "[INFO] $$file: OK";\
    done

