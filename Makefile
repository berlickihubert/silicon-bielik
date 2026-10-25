# Cele testowe sa teraz w Makefile'ach poszczegolnych akceleratorow
# (accelerators/<nazwa>/Makefile); ten plik tylko je wywoluje, zeby stare
# polecenia (make accelerator_top ...) dzialaly jak wczesniej.

WS_DIR := accelerators/SystolicTableAcceleratorWeightStationary
HW_DIR := accelerators/SystolicTableAcceleratorHardcodedWeights
HI_DIR := accelerators/SystolicTableAcceleratorHierarchical

.PHONY: test systolic_array compute_core accelerator_top accelerator_top_hardcoded accelerator_top_hierarchical

test:
	$(MAKE) -C $(WS_DIR)/tests test
	$(MAKE) -C $(HW_DIR)/tests test
	$(MAKE) -C $(HI_DIR)/tests test

systolic_array compute_core accelerator_top:
	$(MAKE) -C $(WS_DIR)/tests $@

accelerator_top_hardcoded:
	$(MAKE) -C $(HW_DIR)/tests $@

accelerator_top_hierarchical:
	$(MAKE) -C $(HI_DIR)/tests accelerator_top
