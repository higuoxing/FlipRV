# Formal check for uart_tx (SymbiYosys: Yosys + BMC/SMT).
# Requires: sby, yosys, and a solver (e.g. yices, z3, bitwuzla — see sby docs).
#
# Usage (from repo root): make -C rtl/uart
#                         make -C rtl/uart check

UART_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SBY ?= sby
JOB := uart_tx

.PHONY: check formal clean help

check formal:
	@command -v "$(SBY)" >/dev/null 2>&1 || { echo "Missing $(SBY) (SymbiYosys). See https://github.com/YosysHQ/sby"; exit 1; }
	cd "$(UART_DIR)" && $(SBY) -f $(JOB).sby

help:
	@echo "make check   — run SymbiYosys BMC on uart_tx (see uart_tx.sby)"
	@echo "make clean   — remove $(JOB)/ work directory"

clean:
	rm -rf "$(UART_DIR)/$(JOB)"
