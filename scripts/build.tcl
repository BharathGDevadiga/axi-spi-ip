# build.tcl - Automates project creation, simulation, and verification
set part "xc7a35tcpg236-1"
set proj_name "axi_spi_build"

puts "==> Step 1: Creating Vivado Project for $part..."
create_project -force $proj_name ./build -part $part

puts "==> Step 2: Adding RTL Sources..."
add_files -norecurse [glob ./src/rtl/*.v]
update_compile_order -fileset sources_1

puts "==> Step 3: Adding Testbench..."
add_files -fileset sim_1 -norecurse ./src/tb/tb_axi_spi.v
update_compile_order -fileset sim_1

puts "==> Step 4: Running Behavioral Simulation..."
set_property top tb_axi_spi [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
launch_simulation

# Check simulation log for [PASS]
set log_file [glob -nocomplain ./build/${proj_name}.sim/sim_1/behav/xsim/simulate.log]
if {[file exists $log_file]} {
    set fp [open $log_file r]
    set log_data [read $fp]
    close $fp

    if {[string match "*\[PASS\]*" $log_data]} {
        puts "\n=========================================="
        puts "   BUILD SUCCESS: All tests verified!"
        puts "==========================================\n"
        exit 0
    } else {
        puts "\n=========================================="
        puts "   BUILD FAILED: Test failed or timed out!"
        puts "==========================================\n"
        exit 1
    }
} else {
    puts "Error: simulate.log not found."
    exit 1
}
