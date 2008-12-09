############################################################
# Distribution Makefile for the Blockdevices framework.
############################################################

.PHONY: configure install clean

all: configure man

BTDIR := ../../../quattor-build-tools

_btincl := $(shell ls $(BTDIR)/quattor-buildtools.mk 2>/dev/null || \
             echo quattor-buildtools.mk)

include $(_btincl)

AII_MODULES := $(shell ls *.pm.cin 2>/dev/null|sed 's/.pm.cin//')
AII_PM := $(addsuffix .pm, $(AII_MODULES))
AII_POD := $(addsuffix .pod, $(AII_MODULES))
AII_MAN := $(addsuffix .8.gz, $(addprefix aii-, $(AII_MODULES) ))

TPL_FILES := $(shell ls TPL/*.tpl.cin|sed 's/.tpl.cin/.tpl/' 2>/dev/null)

_SRC_FILES += $(addsuffix .cin,$(AII_PM) $(TPL_FILES) )
_DIRTY_TPL_FILES += $(addsuffix .cin,$(TPL_FILES) )

PMPATH = $(QTTR_PERLLIB)/$(PACKAGE_PATH)

configure: check $(AII_PM) $(TPL_FILES) $(AII_POD)

install: check configure man

	@echo installing...
	@mkdir -p $(PREFIX)/$(QTTR_MAN)/man8
	@mkdir -p $(PREFIX)/$(PMPATH)
	@mkdir -p $(PREFIX)/$(QTTR_DOC)
	@mkdir -p $(PREFIX)/$(PAN_TEMPLATESDIR)/$(PAN_NAMESPACE_SDIR)/$(PAN_QUATTOR_NS)/aii/$(COMP)
	@mkdir -p $(PREFIX)/$(NCM_COMP)

	@for i in $(AII_PM); do \
                install -m 0644 $$i $(PREFIX)/$(NCM_COMP); \
        done

	@for i in LICENSE ChangeLog README; do \
                install -m 0644 $$i $(PREFIX)/$(QTTR_DOC)/$$i ; \
        done

	@for i in $(AII_MAN); do \
                install -m 0644 $$i $(PREFIX)/$(QTTR_MAN)/man8/$$i ; \
        done

	@for i in $(TPL_FILES) ; do \
                install -m 0644 $$i $(PREFIX)/$(PAN_TEMPLATESDIR)/$(PAN_NAMESPACE_SDIR)/$(PAN_QUATTOR_NS)/aii/$(COMP) ; \
        done

clean::
	@echo cleaning $(NAME) files...
	@for i in $(AII_PM) $(TPL_FILES); do \
                file=`basename $$i .pm` ; \
                rm -f $$i{,*.bak} $$file.pod aii-$$file.8.gz; \
	done

man: configure
	@for i in $(AII_POD); do \
                file=`basename $$i .pod` ; \
                pod2man $(_podopt) $$i > aii-$$file.$(MANSECT) ; \
                gzip -f aii-$$file.$(MANSECT) ; \
        done
