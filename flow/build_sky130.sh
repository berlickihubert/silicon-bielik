#!/usr/bin/env bash
set -e


# parametry
MEM_BACKEND=GENERIC   # GENERIC albo SKY130_SRAM

ROOT="/home/hubert/Desktop/studia/praca-inzynierska/silicon-bielik"
HERE="$ROOT/flow"
OPENLANE_SRC="$HERE/openlane2-src"
SV2V="$ROOT/scripts/work/sv2v"
SRC="$ROOT/src/SystolicTableAcceleratorWeightStationary"
VENDOR="$ROOT/vendor/sky130_sram"
CONFIGS="$HERE/configs"

export PATH="/nix/var/nix/profiles/default/bin:$PATH"

if [ ! -d "$OPENLANE_SRC" ]; then
    echo "klonowanie OpenLane 2 bo nie ma"
    git clone --depth 1 https://github.com/efabless/openlane2 "$OPENLANE_SRC"
fi

if [ ! -x "$SV2V" ]; then
    echo "pobieranie sv2v bo nie ma"
    mkdir -p "$(dirname "$SV2V")"
    curl -sL "https://github.com/zachjs/sv2v/releases/download/v0.0.13/sv2v-Linux.zip" -o "$(dirname "$SV2V")/sv2v.zip"
    unzip -p "$(dirname "$SV2V")/sv2v.zip" "*/sv2v" > "$SV2V"
    chmod +x "$SV2V"
fi

if [ "$MEM_BACKEND" = "SKY130_SRAM" ]; then
    mkdir -p "$VENDOR"
    BASE_URL="https://raw.githubusercontent.com/VLSIDA/sky130_sram_macros/main/sky130_sram_1kbyte_1rw1r_32x256_8"
    for f in sky130_sram_1kbyte_1rw1r_32x256_8.v \
             sky130_sram_1kbyte_1rw1r_32x256_8.lef \
             sky130_sram_1kbyte_1rw1r_32x256_8_TT_1p8V_25C.lib \
             sky130_sram_1kbyte_1rw1r_32x256_8.gds; do
        if [ ! -f "$VENDOR/$f" ]; then
            echo "pobieranie $f"
            curl -sL "$BASE_URL/$f" -o "$VENDOR/$f"
        fi
    done
fi

if [ "$MEM_BACKEND" = "GENERIC" ]; then
    CONFIG="$CONFIGS/sky130_generic.json"
elif [ "$MEM_BACKEND" = "SKY130_SRAM" ]; then
    CONFIG="$CONFIGS/sky130_sram.json"
else
    echo "nieznany MEM_BACKEND: $MEM_BACKEND"
    exit 1
fi

SV_FILES=(
    "$SRC/ProcessingElementWeightStationary.sv"
    "$SRC/SystolicTableWeightStationary.sv"
    "$SRC/DataDelay.sv"
    "$SRC/ComputeCore.sv"
    "$SRC/MemoryBuffer.sv"
)
if [ "$MEM_BACKEND" = "SKY130_SRAM" ]; then
    SV_FILES+=("$SRC/Sky130SramMacro.sv")
fi
SV_FILES+=(
    "$SRC/AxiStreamSlave.sv"
    "$SRC/AxiStreamMaster.sv"
    "$SRC/AcceleratorFSM.sv"
    "$SRC/AcceleratorTop.sv"
)

"$SV2V" "${SV_FILES[@]}" > "$CONFIGS/AcceleratorTop.v"

nix develop --experimental-features "nix-command flakes" --accept-flake-config "$OPENLANE_SRC" \
    -c openlane "$CONFIG" --run-tag "$MEM_BACKEND" --overwrite

RUN_DIR="$CONFIGS/runs/$MEM_BACKEND"
echo
echo "run dir: $RUN_DIR"
echo "metrics: $RUN_DIR/final/metrics.json"
