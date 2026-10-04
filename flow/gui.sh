#!/usr/bin/env bash
set -e


RUN_DIR="configs/runs/GENERIC"
STAGE="final/odb"
# inne dostepne cornery (nazwa pliku: sky130_fd_sc_hd__<corner>.lib):
#   tt_025C_1v80   25 stopni C, 1.80V normalne warunki
#   ss_100C_1v60   worst-case 100C, 1.60V (najwolniejsze tranzystory)
#   ff_n40C_1v95    -40C, 1.95V (najszybsze tranzystory)
CORNER="ss_100C_1v60"

HERE="/home/hubert/Desktop/studia/praca-inzynierska/silicon-bielik/flow"
OPENLANE_SRC="$HERE/openlane2-src"
RUN_DIR="$HERE/$RUN_DIR"

ODB=$(find "$RUN_DIR/$STAGE" -iname "*.odb" | head -1)
SDC="$RUN_DIR/final/sdc/AcceleratorTop.sdc"
SPEF="$RUN_DIR/final/spef/nom/AcceleratorTop.nom.spef"
LIB=$(find /home/hubert/.volare -path "*sky130A*sky130_fd_sc_hd*lib/sky130_fd_sc_hd__${CORNER}.lib" | head -1)

SCRIPT=$(mktemp --suffix=.tcl)
trap 'rm -f "$SCRIPT"' EXIT

cat > "$SCRIPT" <<EOF
read_liberty "$LIB"
read_db "$ODB"
read_sdc "$SDC"
read_spef "$SPEF"
puts "gotowe - current_design: [current_design], corner: $CORNER, etap: $STAGE"
foreach c [all_clocks] { puts "zegar: [get_name \$c]" }
report_checks -path_delay max -digits 3
report_design_area
report_power
EOF

export PATH="/nix/var/nix/profiles/default/bin:$PATH"
nix develop --experimental-features "nix-command flakes" --accept-flake-config "$OPENLANE_SRC" \
    -c openroad -gui "$SCRIPT"
