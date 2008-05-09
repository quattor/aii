###############################################################################
# quattor-test.mk
#
# Quattor unit testing makefile
#
# Marco Emilio Poleggi <marco.poleggi>@cern.ch
#
# $Id$
###############################################################################


###############################################################################
# General settings
###############################################################################

# test programs subdir local to component directory
_quattor_testdir=t

# test file list
QTTR_TESTLIST=test-list

# test harness program
_quattor_testharn=run-all-tests
