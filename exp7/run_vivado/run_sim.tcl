#=============================================================================
#  run_sim.tcl
#  One-step: create project -> compile -> run simulation
#
#  Usage: vivado -mode batch -source run_sim.tcl
#=============================================================================

# ---- Step 1: Create or Open Project --------------------------------------
if {[catch {open_project ./project/loongson.xpr}]} {
    puts "  [INFO] Project not found, creating new one..."
    source ./create_project.tcl
} else {
    puts "  [INFO] Project opened."
}

# ---- Step 2: Launch Simulation -------------------------------------------
puts "  [INFO] Launching simulation..."
reset_simulation
launch_simulation

# ---- Step 3: Run Simulation ----------------------------------------------
puts "  [INFO] Running simulation (200us)..."
run 200us

# ---- Step 4: Done --------------------------------------------------------
puts ""
puts "========================================================================="
puts "  Simulation complete (200us)"
puts "  Open Vivado GUI -> Flow Navigator -> Open Waveform to view signals."
puts "========================================================================="

close_sim
close_project
