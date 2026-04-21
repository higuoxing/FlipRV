# Tang Nano 20K — Yosys + nextpnr-himbaechel + Apicula
REPO_ROOT := $(abspath ../..)
BOARD     ?= tangnano20k
HW        ?=

# Setup Tools
YOSYS          ?= yosys
NEXTPNR        ?= nextpnr-himbaechel
GOWIN_PACK     ?= gowin_pack
OPENFPGALOADER ?= openFPGALoader

# Device Config
DEVICE            ?= GW2AR-LV18QN88C8/I7
FAMILY            ?= GW2A-18C
GOWIN_PACK_DEVICE ?= GW2A-18C

# Paths
BUILD_DIR  := $(REPO_ROOT)/build/$(HW)
BITSTREAM  := $(BUILD_DIR)/$(HW).fs
JSON_SYNTH := $(BUILD_DIR)/$(HW)-syn.json
JSON_PNR   := $(BUILD_DIR)/$(HW)-pnr.json
CST        ?= $(REPO_ROOT)/boards/$(BOARD)/constraints.cst
RECEIPT    := $(REPO_ROOT)/hw/$(HW)/receipt.txt

# Validation: skip check for 'help' or 'clean'
ifeq ($(filter help clean,$(MAKECMDGOALS)),)
  ifeq ($(HW),)
    $(error HW is required. Example: make HW=uart_tx_example)
  endif
  # Use \# to prevent Make from treating it as a comment
  # Use addprefix to handle the pathing safely on the Make side
  SOURCES := $(addprefix $(REPO_ROOT)/, $(shell grep -v '^\#' $(RECEIPT) | awk '{print $$1}'))
endif

.PHONY: all flash bitstream help clean

all: flash

bitstream: $(BITSTREAM)

$(BITSTREAM): $(SOURCES) $(CST)
	@mkdir -p $(BUILD_DIR)
	$(YOSYS) -p "read_verilog -I $(REPO_ROOT) $(SOURCES); synth_gowin -top top -json $(JSON_SYNTH)"
	$(NEXTPNR) --device $(DEVICE) --vopt family=$(FAMILY) --vopt cst=$(CST) \
		--json $(JSON_SYNTH) --write $(JSON_PNR)
	$(GOWIN_PACK) --device $(GOWIN_PACK_DEVICE) -o $(BITSTREAM) $(JSON_PNR)

flash: $(BITSTREAM)
	$(OPENFPGALOADER) -f -b $(BOARD) $(BITSTREAM)

clean:
	rm -rf $(REPO_ROOT)/build

help:
	@echo "Usage: make HW=<project_name> [target]"
	@echo "Targets: bitstream, flash, clean"
