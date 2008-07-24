####################################################################
# Distribution Makefile
####################################################################

.PHONY: configure install clean

all: configure

#
# BTDIR needs to point to the location of the build tools
#
BTDIR := ../quattor-build-tools
#
#
_btincl   := $(shell ls $(BTDIR)/quattor-buildtools.mk 2>/dev/null || \
             echo quattor-buildtools.mk)
include $(_btincl)



####################################################################
# Configure
####################################################################

AII_SOURCES 	:= aii-installfe aii-shellfe aii-dhcp aii-osinstall aii-nbp
TPL_FILES   := $(shell ls \
	TPL/{$(PAN_QUATTOR_NS)/$(COMP),$(PAN_PAN_STRUCT_NS),$(PAN_SITE_NS),$(PAN_OS_NS)/i386_sl3}/*.tpl.cin \
	TPL/pro_*.tpl.cin 2>/dev/null \
	    | sed -e 's/.tpl.cin/.tpl/' || echo)

AII_TEMPLATES	:= \
	quattor/aii/config.tpl\
	quattor/aii/schema.tpl\
	site/aii.tpl \
	os/i386_sl3/aii.tpl

AII_EXAMPLES 	:= \
	localboot.cfg sl_ks.conf \
	sl_pxe.conf dhcpd.conf \
	tftp.example \
	aii-shellfe.conf aii-installfe.conf \
	aii-dhcp.conf aii-nbp.conf aii-osinstall.conf

AII_DOC		:= aii.pod

AII_TPL_FILES       := $(addprefix TPL/, $(AII_TEMPLATES) )
_SRC_FILES          += $(addsuffix .cin, $(AII_SOURCES) $(AII_TPL_FILES) )
_DIRTY_TPL_FILES    += $(addsuffix .cin, $(AII_TPL_FILES) )

configure: tplclean check \
	$(AII_SOURCES) aii-installack.cgi \
	$(addprefix eg/, $(addsuffix .conf, ${AII_SOURCES}))\
	$(TPL_FILES) \
	$(AII_DOC)

####################################################################
# Install
####################################################################

install: configure man
	@echo installing ...
	@mkdir -p $(PREFIX)/$(QTTR_SBIN)
	@mkdir -p $(PREFIX)/$(QTTR_ETC)
	@mkdir -p $(PREFIX)/$(QTTR_MAN)/man$(MANSECT)
	@mkdir -p $(PREFIX)/$(PAN_TEMPLATESDIR)/$(PAN_NAMESPACE_SDIR)/$(PAN_QUATTOR_NS)/$(COMP)
	@mkdir -p $(PREFIX)/$(PAN_TEMPLATESDIR)/$(PAN_NAMESPACE_SDIR)/$(PAN_SITE_NS)
	@mkdir -p $(PREFIX)/$(PAN_TEMPLATESDIR)/$(PAN_NAMESPACE_SDIR)/$(PAN_OS_NS)/i386_sl3
	@mkdir -p $(PREFIX)/$(QTTR_DOC)
	@mkdir -p $(PREFIX)/$(QTTR_DOC)/eg
	@mkdir -p $(PREFIX)/$(QTTR_LIB)/aii
	@mkdir -p $(PREFIX)/$(QTTR_LIB)/aii/nbp
	@mkdir -p $(PREFIX)/$(QTTR_LIB)/aii/osinstall

	@for i in $(AII_SOURCES) aii-installack.cgi ; do \
		install -m 0755 $$i $(PREFIX)/$(QTTR_SBIN)/$$i ; \
	done
	@for i in $(AII_SOURCES) ; do \
		install -m 0444 $$i.$(MANSECT).gz \
			$(PREFIX)$(QTTR_MAN)/man$(MANSECT)/$$i.$(MANSECT).gz ; \
	done
	@for i in $(AII_DOC) ; do \
		file=`basename $$i .pod`; \
		install -m 0444 $$file.$(MANSECT).gz \
			$(PREFIX)$(QTTR_MAN)/man$(MANSECT)/$$file.$(MANSECT).gz ; \
	done
	@for i in LICENSE ChangeLog README ; do \
		install -m 0444 $$i $(PREFIX)/$(QTTR_DOC)/$$i ; \
	done
	@for i in $(AII_EXAMPLES) ; do \
		install -m 0444 eg/$$i $(PREFIX)/$(QTTR_DOC)/eg/$$i ; \
	done
	@for i in $(AII_TEMPLATES) ; do \
		install -m 0444 TPL/$$i $(PREFIX)/$(PAN_TEMPLATESDIR)/$(PAN_NAMESPACE_SDIR)/$$i ; \
	done

	@install -m 0444 eg/localboot.cfg $(PREFIX)/$(QTTR_LIB)/aii/nbp/localboot.cfg

	@install -m 0444 eg/sl_pxe.conf $(PREFIX)/$(QTTR_LIB)/aii/nbp/sl_pxe.conf

	@install -m 0444 eg/sl_ks.conf $(PREFIX)/$(QTTR_LIB)/aii/osinstall/sl_ks.conf

man: configure
	@for i in $(AII_SOURCES) $(AII_DOC) ; do \
		file=`basename $$i .pod`; \
		echo creating man page for $$file ; \
		pod2man $(_podopt) $$i > $$file.$(MANSECT) ; \
		gzip -f $$file.$(MANSECT) ; \
	done

####################################################################


clean::
	@echo cleaning $(NAME) files ...
	@rm -f $(AII_SOURCES) aii-installack.cgi $(AII_DOC) \
		$(addprefix eg/, $(TPL_FILES) $(addsuffix .conf, $(AII_SOURCES)))\
		$(TPL_FILES) $(addsuffix .bak, $(TPL_FILES) $(addsuffix .cin, $(TPL_FILES) ) )

