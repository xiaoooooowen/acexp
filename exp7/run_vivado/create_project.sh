#!/bin/bash
# Create Vivado project for exp7 (Loongson CPU)
# Usage: bash create_project.sh

VIVADO="/d/Xilinx/Vivado/2019.2/bin/vivado"

if [ ! -f "$VIVADO" ]; then
    echo "[ERROR] Vivado not found at $VIVADO"
    echo "[ERROR] Please update VIVADO path in this script"
    exit 1
fi

echo "[INFO] Creating Vivado project ..."
"$VIVADO" -source create_project.tcl -mode tcl -notrace

if [ $? -eq 0 ]; then
    echo "[INFO] Project created successfully!"
    echo "[INFO] Project file: $(pwd)/project/loongson.xpr"
else
    echo "[ERROR] Failed to create project!"
fi
