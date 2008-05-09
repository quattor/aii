###############################################################################
# quattor-component.mk
###############################################################################
#
# Basic QUATTOR NCM component Makefile
#
# German Cancio <German.Cancio@cern.ch>
# Marco Emilio Poleggi <Marco.Emilio.Poleggi@cern.ch>
#
# $Id$
###############################################################################

.PHONY: configure install clean tplconvert tplcvssync tplclean

all: configure

#
# BTDIR needs to point to the location of the build tools
#
BTDIR := ../../../quattor-build-tools
#
#
_btincl   := $(shell ls $(BTDIR)/quattor-buildtools.mk 2>/dev/null || \
             echo quattor-buildtools.mk)
include $(_btincl)


OLD_TPL_FILES	:= $(subst $(TPL_CIN_EXT),$(TPL_EXT),\
	$(shell cd TPL 2>/dev/null && ls pro_*$(TPL_CIN_EXT) 2>/dev/null || echo))
OPT_TPL_FILES	:= $(filter-out $(OLD_TPL_FILES) $(MND_TPL_FILES),\
	$(subst $(TPL_CIN_EXT),$(TPL_EXT),\
		$(shell cd TPL 2>/dev/null && ls *$(TPL_CIN_EXT) 2>/dev/null || echo)))
# New tpl files based on namespaces must be in TPL/
NEW_TPL_FILES	:= $(MND_TPL_FILES) $(OPT_TPL_FILES)

# mandatory files
MND_TPL_FILES	:= schema$(TPL_EXT) config$(TPL_EXT)
MND_COMP_FILES	:= $(COMP).pm $(COMP).pod
_MND_CVS_FILES	+= $(addsuffix .cin,\
	$(addprefix TPL/,$(MND_TPL_FILES)) $(MND_COMP_FILES))


####################################################################
# Configure
####################################################################

# check for mandatory files and information tags
_SRC_FILES			+= $(addsuffix .cin,\
    $(addprefix TPL/,$(NEW_TPL_FILES)) $(MND_COMP_FILES))
_DIRTY_TPL_FILES	+= $(addsuffix .cin,$(addprefix TPL/,$(NEW_TPL_FILES)))

compcheck: tplclean check
	@echo "[INFO] Checking $(COMP)'s files and directories...";\
	if [ ! -d TPL ]; then\
		echo "[ERROR] TPL/: mandatory directory missing" >&2;\
		exit 1;\
	fi;\

configure: compcheck\
	$(MND_COMP_FILES) $(NAME).$(NCM_MANSECT) $(NAME).html $(addprefix TPL/,$(NEW_TPL_FILES))


####################################################################
# Install
####################################################################
INSTALL_DIRS	:= $(addprefix $(PREFIX)/,\
	$(NCM_COMP)\
	$(NCM_DATA)/$(COMP)\
	$(NCM_TPL_FILES)/$(COMP)\
	$(QTTR_DOC)\
	$(QTTR_MAN)/man$(NCM_MANSECT)\
)
install: configure
	@echo "[INFO] installing..."
	@mkdir -p $(INSTALL_DIRS)
	@install -m 0555 $(COMP).pm $(PREFIX)/$(NCM_COMP)/$(COMP).pm
	@install -m 0444 $(NAME).$(NCM_MANSECT) \
		$(PREFIX)/$(QTTR_MAN)/man$(NCM_MANSECT)/$(NAME).$(NCM_MANSECT)
	@for i in $(_DOC_FILES) ; do \
		install -m 0444 $$i $(PREFIX)/$(QTTR_DOC)/$$i;\
	done
	@[ -d TPL ] && cd TPL &&\
		for i in $(NEW_TPL_FILES); do \
			install -m 0444 $$i $(PREFIX)/$(NCM_TPL_FILES)/$(COMP)/$$i;\
		done || :
	@[ -d DATA ] && cd DATA &&\
		for i in *; do \
			install -m 0444 $$i $(PREFIX)/$(NCM_DATA)/$(COMP)/$$i;\
		done || :
	@[ -d DOC ] && cd DOC &&\
		for i in *; do \
			install -m 0444 $$i $(PREFIX)/$(QTTR_DOC)/$$i;\
		done || :


###############################################################################
# Convert the namespace structure of any shipped template from pseudo-flat
# to directory-based, that is, stuff like 'foo_component_bar' becomes 
# 'foo/component/bar/{config, schema}'.
# Deprecated words are removed/commented before the namespace converision
###############################################################################
TPLS_TO_CONV	:= $(shell cd ./TPL 2>/dev/null && ls pro_*$(TPL_CIN_EXT) 2>/dev/null || echo)
CONV_EXE		:= ../../../../util/misc/ncmtplconvert
OUT_DIR			:= ./
ifneq ($(NCMTPLCONV_OUT_DIR),)
	OUT_DIR		:= $(NCMTPLCONV_OUT_DIR)
endif
# file name mappings used by 'tplcvssync'
_names_map_file	:= .tpl-names.map
_map_sep		:= :
tplconvert:
	@echo "[INFO] Converting template structure to full-namespace-based...";\
	if [ "$(TPLS_TO_CONV)" ]; then\
		cd TPL;\
		$(CONV_EXE) --out-dir=$(OUT_DIR) --no-subdir --force --name-map-file=$(_names_map_file)\
	 		--line-model="^\s*#+\s+type\s+definition\s+[_[:alpha:][:digit:]@]+.*$$"\
			--sw-tpl-pattern="^.*?pro_software_component_$(COMP)\$(TPL_EXT)"\
			--dec-tpl-pattern="^.*?pro_declaration_component_$(COMP)\$(TPL_EXT)"\
			--map-rule="pro_software_component=$(PAN_COMP_NS)"\
			--map-rule="pro_declaration_component=$(PAN_COMP_NS)"\
			--map-rule="pro_declaration_structures=quattor/schema"\
			--map-rule="include\s+pro_declaration_structure_validation_functions\s*;="\
			--map-rule="include\s+pro_declaration_types\s*;="\
			--map-rule="pro_declaration_functions_general=pan/functions"\
			--map-rule="pro_declaration_functions_$(COMP)=$(PAN_COMP_NS)/$(COMP)/functions"\
			--map-rule="pro_declaration_functions_@COMP@=$(PAN_COMP_NS)/@COMP@/functions"\
			--dont-touch="$(COMP)"\
			--dont-touch="@COMP@"\
			$(TPLS_TO_CONV);\
		[ $$? -ne 0 ] && exit 1;\
		echo "[INFO] Please REVIEW the resulting templates in TPL/:";\
		cut -d $(_map_sep) -f 3 $(_names_map_file);\
		echo "[INFO] then run 'make tplcvssync' to remove old templates and add new ones";\
	else\
		echo "[INFO] Nothing to do here";\
	fi

# This includes are useless since stated upstream in 'pan-templates' package
#--map-rule="pro_declaration_structure_validation_functions=pan/functions/validation"\
#--map-rule="pro_declaration_types=pan/types"\


###############################################################################
# Add in CVS new templates coming from tplconvert and remove old ones. The
# _names_map_file is used as a reference. Any old tpl and extra namespace
# subdirectory found in TPL/ is removed as well
###############################################################################
tplcvssync:	compcheck
	@echo "[INFO] Synchronizing templates in CVS...";\
	cd TPL/;\
	files_to_rm='';\
	files_to_add='';\
	error=0;\
	if [ ! -f $(_names_map_file) ]; then\
		echo "[INFO] Nothing to do here";\
		exit;\
	fi;\
	for map in `cat $(_names_map_file)`; do\
		old=`echo $$map | cut -d $(_map_sep) -f 1`$(TPL_CIN_EXT);\
		[ -f $$old ] && files_to_rm=$$files_to_rm' '$$old;\
		new_wrong=`echo $$map | cut -d $(_map_sep) -f 2`$(TPL_CIN_EXT);\
		[ -f $$new_wrong ] && files_to_rm=$$files_to_rm' '$$new_wrong;\
		new=`echo $$map | cut -d $(_map_sep) -f 3`;\
		if [ -f $$new ]; then\
			if ! cvs log $$new >/dev/null 2>&1; then\
				files_to_add=$$files_to_add' '$$new;\
			else\
				echo "[WARN] '$$new': already in CVS, skipping..." >&2;\
			fi;\
		fi;\
	done;\
	if [ "$$files_to_rm" ]; then\
		rm -f $$files_to_rm;\
		cvs remove $$files_to_rm || error=1;\
	fi;\
	[ "$$files_to_add" ] && (cvs add $$files_to_add || error=1);\
	if [ $$error -ne 0 ]; then\
		echo "[ERROR] Something went wrong" >&2;\
		exit 1;\
	fi;\
	echo "[INFO] Please REVIEW the resulting templates in TPL/: $$files_to_add";\
	echo "[INFO] tip: try 'make compcheck'";\
	echo "[INFO] then call 'make minorversion' to commit changes in CVS"


####################################################################


clean::
	@echo [INFO] cleaning $(NAME) files ...;\
	rm -f $(COMP) $(COMP).pod $(COMP).pm $(NAME).$(NCM_MANSECT) \
		ncm-$(COMP).html *~ *.bak\
		$(addprefix TPL/,$(NEW_TPL_FILES) *~ *.bak $(_names_map_file))

