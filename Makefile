# =============================================================================
# WISHBONE-MEMORY — Simulation Makefile (Vivado XSim)
#
# Usage:
#   make          # batch mode (default)
#   make GUI=1    # Open Vivado waveform GUI (all signals auto-loaded)
#   make clean    # Remove build/ folder entirely
#   make help     # Print this message
# =============================================================================

GUI ?= 0

TOP      := wb_vip_tb
BUILD_DIR := build

# TCL wave script — generated every make run
WAVE_TCL := $(BUILD_DIR)/wave.tcl

# ------------------------------------------------------------
# Source lists
# ------------------------------------------------------------
ALL_SRCS := \
    interface/wb_if.sv           \
    source/dual_port_mem.sv      \
    source/mem.sv                \
    source/wishbone_mem_ctrlr.sv \
    source/wb_mem.sv             \
    vip/wb/wb.svh                \
    testbench/wb_mem_vip_tb.sv

# Absolute repo root
ROOT     := $(CURDIR)
ABS_SRCS := $(addprefix $(ROOT)/,$(ALL_SRCS))

# ------------------------------------------------------------
# XSim tool flags
# ------------------------------------------------------------
XVLOG := xvlog
XELAB := xelab
XSIM  := xsim

XVLOG_FLAGS := --sv --incr \
               -i $(ROOT) \
               --work work=$(ROOT)/$(BUILD_DIR) \
               --log xvlog.log

XELAB_FLAGS := --debug all \
               --timescale 1ns/1ps \
               -L work=$(ROOT)/$(BUILD_DIR) \
               --log xelab.log

ifeq ($(GUI),1)
    XSIM_FLAGS := --gui --tclbatch $(ROOT)/$(WAVE_TCL) --log xsim.log
else
    XSIM_FLAGS := --runall --log xsim.log
endif

# ------------------------------------------------------------
# Targets
# ------------------------------------------------------------
.PHONY: all run clean help wave_tcl

all: run

run: $(BUILD_DIR)/xsim.dir/$(TOP)/xsimk wave_tcl
	@echo ""
	@if [ "$(GUI)" = "1" ]; then \
		echo ">>> Opening GUI with waveforms: $(TOP)"; \
	else \
		echo ">>> Running simulation: $(TOP)"; \
	fi
	@echo ""
	cd $(BUILD_DIR) && $(XSIM) $(TOP) $(XSIM_FLAGS)

$(BUILD_DIR)/xsim.dir/$(TOP)/xsimk: $(ALL_SRCS) | $(BUILD_DIR)
	@echo ">>> Compiling sources  →  $(BUILD_DIR)"
	cd $(BUILD_DIR) && $(XVLOG) $(XVLOG_FLAGS) $(ABS_SRCS)
	@echo ">>> Elaborating: $(TOP)"
	cd $(BUILD_DIR) && $(XELAB) $(XELAB_FLAGS) $(TOP) -s $(TOP)

# Write wave.tcl line by line — no heredoc (not valid in Makefile)
wave_tcl: | $(BUILD_DIR)
	@echo ">>> Generating wave script  →  $(WAVE_TCL)"
	@echo 'log_wave -r /'                                            > $(WAVE_TCL)
	@echo 'create_wave_config wb_mem_waves'                         >> $(WAVE_TCL)
	@echo 'add_wave_divider "Clock and Reset"'                      >> $(WAVE_TCL)
	@echo 'add_wave -color yellow            /wb_vip_tb/clk_i'      >> $(WAVE_TCL)
	@echo 'add_wave -color red               /wb_vip_tb/rst_i'      >> $(WAVE_TCL)
	@echo 'add_wave_divider "WISHBONE Bus"'                         >> $(WAVE_TCL)
	@echo 'add_wave -color cyan              /wb_vip_tb/intf/cyc_i' >> $(WAVE_TCL)
	@echo 'add_wave -color cyan              /wb_vip_tb/intf/stb_i' >> $(WAVE_TCL)
	@echo 'add_wave -color cyan              /wb_vip_tb/intf/we_i'  >> $(WAVE_TCL)
	@echo 'add_wave -color green -radix hex  /wb_vip_tb/intf/addr_i'>> $(WAVE_TCL)
	@echo 'add_wave -color green -radix hex  /wb_vip_tb/intf/data_i'>> $(WAVE_TCL)
	@echo 'add_wave -color green -radix bin  /wb_vip_tb/intf/sel_i' >> $(WAVE_TCL)
	@echo 'add_wave -color orange            /wb_vip_tb/intf/ack_o' >> $(WAVE_TCL)
	@echo 'add_wave -color orange -radix hex /wb_vip_tb/intf/data_o'>> $(WAVE_TCL)
	@echo 'add_wave_divider "Memory Interface"'                     >> $(WAVE_TCL)
	@echo 'add_wave -color cyan              /wb_vip_tb/dut/ctrlr_inst/mem_we_i'    >> $(WAVE_TCL)
	@echo 'add_wave -color green -radix hex  /wb_vip_tb/dut/ctrlr_inst/mem_addr_i'  >> $(WAVE_TCL)
	@echo 'add_wave -color green -radix hex  /wb_vip_tb/dut/ctrlr_inst/mem_wdata_i' >> $(WAVE_TCL)
	@echo 'add_wave -color green -radix bin  /wb_vip_tb/dut/ctrlr_inst/mem_wstrb_i' >> $(WAVE_TCL)
	@echo 'add_wave -color orange -radix hex /wb_vip_tb/dut/ctrlr_inst/mem_rdata_o' >> $(WAVE_TCL)
	@echo 'add_wave_divider "DUT Outputs"'                          >> $(WAVE_TCL)
	@echo 'add_wave -color orange            /wb_vip_tb/dut/ack_o'  >> $(WAVE_TCL)
	@echo 'add_wave -color orange -radix hex /wb_vip_tb/dut/data_o' >> $(WAVE_TCL)
	@echo 'run all'                                                  >> $(WAVE_TCL)
	@echo 'save_wave_config $(ROOT)/wave.wcfg'                      >> $(WAVE_TCL)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	@echo ">>> Removing build/"
	rm -rf build/

help:
	@echo ""
	@echo "  WISHBONE-MEMORY — Vivado XSim Makefile"
	@echo "  ──────────────────────────────────────"
	@echo "  make        batch mode (default)"
	@echo "  make GUI=1  Open waveform GUI"
	@echo "  make clean  Remove build/ folder"
	@echo "  ──────────────────────────────────────"
	@echo ""