PYTHON_BIN ?= $(PWD)/.venv/bin/python
VENV_DIR   := $(abspath $(dir $(PYTHON_BIN))/..)
SV_DIR     := $(PWD)/src/SystolicTableAcceleratorWeightStationary

.PHONY: systolic_array compute_core accelerator_top

systolic_array:
	bash -c '\
		unset TEST SIM_BUILD VERILOG_SOURCES TOPLEVEL MODULE PARAMS EXTRA_ARGS COMPILE_ARGS; \
		source $(VENV_DIR)/bin/activate && \
		$(MAKE) -f Makefile.test \
			SIM=$(SIM) \
			TOPLEVEL=SystolicTableWeightStationary \
			MODULE=tests.SystolicArrayTest \
			SIM_BUILD=sim_build_systolic_array \
			VERILOG_SOURCES="$(SV_DIR)/ProcessingElementWeightStationary.sv $(SV_DIR)/SystolicTableWeightStationary.sv" \
			PARAMS="ROWS=3 COLS=4"'

compute_core:
	bash -c '\
		unset TEST SIM_BUILD VERILOG_SOURCES TOPLEVEL MODULE PARAMS EXTRA_ARGS COMPILE_ARGS; \
		source $(VENV_DIR)/bin/activate && \
		$(MAKE) -f Makefile.test \
			SIM=$(SIM) \
			TOPLEVEL=ComputeCore \
			MODULE=tests.ComputeCoreTest \
			SIM_BUILD=sim_build_compute_core \
			VERILOG_SOURCES="$(SV_DIR)/DataDelay.sv $(SV_DIR)/ProcessingElementWeightStationary.sv $(SV_DIR)/SystolicTableWeightStationary.sv $(SV_DIR)/ComputeCore.sv" \
			PARAMS="ROWS=3 COLS=4"'

accelerator_top:
	bash -c '\
		unset TEST SIM_BUILD VERILOG_SOURCES TOPLEVEL MODULE PARAMS EXTRA_ARGS COMPILE_ARGS; \
		source $(VENV_DIR)/bin/activate && \
		$(MAKE) -f Makefile.test \
			SIM=$(SIM) \
			TOPLEVEL=AcceleratorTop \
			MODULE=tests.AcceleratorTopTest \
			SIM_BUILD=sim_build_accelerator_top \
			VERILOG_SOURCES="$(SV_DIR)/DataDelay.sv $(SV_DIR)/ProcessingElementWeightStationary.sv $(SV_DIR)/SystolicTableWeightStationary.sv $(SV_DIR)/ComputeCore.sv $(SV_DIR)/MemoryBuffer.sv $(SV_DIR)/AxiStreamSlave.sv $(SV_DIR)/AxiStreamMaster.sv $(SV_DIR)/AcceleratorFSM.sv $(SV_DIR)/AcceleratorTop.sv" \
			PARAMS="ROWS=3 COLS=4 ADDR_WIDTH=5 MEM_BACKEND=0"'
