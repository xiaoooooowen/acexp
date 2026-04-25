#=============================================================================
#  create_project.tcl
#  Create Vivado project for exp7 (Loongson CPU 5-stage pipeline SoC)
#
#  Usage:
#    GUI   : vivado -source create_project.tcl
#    Batch : vivado -mode batch -source create_project.tcl
#=============================================================================

# ---- Project Settings -----------------------------------------------------
set project_name "loongson"
set project_dir "./project"
set device_part "xc7a200tfbg676-1"

# ---- Paths (relative to this script) -------------------------------------
set script_dir [file dirname [info script]]
set mycpu_env  [file normalize "$script_dir/../mycpu_env"]
set mycpu_rtl  "$mycpu_env/myCPU"
set soc_rtl    "$mycpu_env/soc_verify/soc_bram/rtl"
set soc_tb     "$mycpu_env/soc_verify/soc_bram/testbench"
set constraints "$mycpu_env/soc_verify/soc_bram/run_vivado/constraints"

puts "========================================================================="
puts "  exp7 Vivado Project Creation"
puts "  Project : $project_name"
puts "  Part    : $device_part"
puts "========================================================================="

# ---- Step 1: Create Project ----------------------------------------------
create_project -force $project_name $project_dir -part $device_part

# ---- Step 2: Add CPU Pipeline RTL Sources --------------------------------
puts {  [1/5] Add CPU core RTL ...}
add_files -norecurse [list \
    [file normalize "$mycpu_rtl/mycpu_top.v"] \
    [file normalize "$mycpu_rtl/if_stage.v"]   \
    [file normalize "$mycpu_rtl/id_stage.v"]   \
    [file normalize "$mycpu_rtl/exe_stage.v"]  \
    [file normalize "$mycpu_rtl/mem_stage.v"]  \
    [file normalize "$mycpu_rtl/wb_stage.v"]   \
    [file normalize "$mycpu_rtl/alu.v"]        \
    [file normalize "$mycpu_rtl/regfile.v"]    \
    [file normalize "$mycpu_rtl/tools.v"]      \
]

# ---- Step 3: Set Include Directories (for `include "mycpu.h") ------------
set_property include_dirs [list \
    [file normalize "$mycpu_rtl"] \
] [current_fileset]

# ---- Step 4: Add SoC Peripheral RTL --------------------------------------
puts {  [2/5] Add SoC peripheral RTL ...}
add_files -norecurse [list \
    [file normalize "$soc_rtl/soc_lite_top.v"]   \
    [file normalize "$soc_rtl/BRIDGE/bridge_1x2.v"] \
    [file normalize "$soc_rtl/CONFREG/confreg.v"]   \
]

# ---- Step 5: Add IP Cores (for synthesis, skip if only simulating) -------
# NOTE: For simulation, IP cores are not needed because:
#   - inst_ram/data_ram: have behavioral models in testbench/sync_ram.v
#   - clk_pll: bypassed when SIMU_USE_PLL=0 (default for simulation)
# For bitstream generation, uncomment below and run:
#   generate_target all [get_files */xilinx_ip/*/*.xci]
# puts {  [3/5] Add IP cores ...}
# set ip_files [glob -nocomplain [file normalize "$soc_rtl/xilinx_ip/*/*.xci"]]
# if {[llength $ip_files] > 0} {
#     add_files -norecurse $ip_files
# }

# ---- Step 6: Add Simulation Files ----------------------------------------
puts {  [3/5] Add simulation files ...}
add_files -fileset sim_1 -norecurse [list \
    [file normalize "$soc_tb/mycpu_tb.v"] \
    [file normalize "$soc_tb/sync_ram.v"] \
]

set_property -name "top" -value "tb_top" -objects [get_filesets sim_1]
set_property -name "xsim.simulate.log_all_signals" -value "1" \
    -objects [get_filesets sim_1]

# ---- Step 7: Add Constraints ---------------------------------------------
puts {  [4/5] Add constraints ...}
set xdc_file [file normalize "$constraints/soc_lite_top.xdc"]
if {[file exists $xdc_file]} {
    add_files -fileset constrs_1 -norecurse $xdc_file
}

# ---- Step 8: Check project settings --------------------------------------
puts {  [5/5] Finalizing ...}

puts "========================================================================="
puts "  Project created successfully!"
puts "  Path: [file normalize $project_dir]/$project_name.xpr"
puts "  Sim top: tb_top"
puts "========================================================================="

# Exit to close Vivado (for batch/scripted usage)
exit
