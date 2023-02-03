# SPDX-License-Identifier: BSD-3-Clause
#
# program_fpga.tcl
#
# Program FPGA with a .bit file
#

# file
set script_file "program_fpga.tcl"

# arguments
set bitfile "design_1_wrapper.bit"
set device xcvu37p_0

# Help information for this script
proc print_help {} {
  variable script_file
  puts "\nDescription:"
  puts "Program FPGA with provided bitfile.\n"
  puts "Syntax:"
  puts "$script_file"
  puts "$script_file -tclargs \[--bitfile <path>\]"
  puts "$script_file -tclargs \[--device  <name>\]"
  puts "$script_file -tclargs \[--help\]\n"
  puts "Usage:"
  puts "Name                   Description"
  puts "-------------------------------------------------------------------------"
  puts "\[--bitfile <path>\] Design bitfile\n"
  puts "\[--device  <name>\] Target device\n"
  puts "\[--help\]           Print help information for this script"
  puts "-------------------------------------------------------------------------\n"
  exit 0
}

# parse arguments
if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--bitfile" { incr i; set bitfile [lindex $::argv $i] }
      "--device"  { incr i; set device [lindex $::argv $i] }
      "--help"    { print_help }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

puts "Programming FPGA (${device}) with $bitfile"

# open hardware manager
open_hw

# connect to local hardware server
connect_hw_server

# open hardware target
open_hw_target

# set programming file
set_property PROGRAM.FILE $bitfile [get_hw_devices ${device}]

# program FPGA
program_hw_devices -verbose [get_hw_devices ${device}]

# exit
close_hw_target
