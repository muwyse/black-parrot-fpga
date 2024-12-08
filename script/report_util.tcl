# SPDX-License-Identifier: BSD-3-Clause
#
# report_util.tcl
#
# Report utilization
#

# file
set script_file "report_util.tcl"

# arguments
set project_name "vcu128_bp"
set util_name "util"

# Help information for this script
proc print_help {} {
  variable script_file
  puts "\nDescription:"
  puts "Run synthesis and implementation.\n"
  puts "Syntax:"
  puts "$script_file"
  puts "$script_file -tclargs \[--project_name <name>\]"
  puts "$script_file -tclargs \[--util_name <name>\]"
  puts "$script_file -tclargs \[--help\]\n"
  puts "Usage:"
  puts "Name                   Description"
  puts "-------------------------------------------------------------------------"
  puts "\[--project_name <name>\] Open project with the specified name. Default"
  puts "                          name is the name of the project from where this"
  puts "                          script was generated.\n"
  puts "\[--help\] Print help information for this script"
  puts "-------------------------------------------------------------------------\n"
  exit 0
}

# parse arguments
if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--project_name" { incr i; set project_name [lindex $::argv $i] }
      "--util_name" { incr i; set util_name [lindex $::argv $i] }
      "--help"         { print_help }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

puts "Reporting utilization for $project_name to $util_name"

# open project
open_project $project_name/$project_name.xpr
open_run impl_1
#report_utilization -name $util_name -spreadsheet_depth 100 -spreadsheet_fil $util_name.xlsx
#report_utilization -spreadsheet_depth 100 -spreadsheet_file $util_name.xlsx
report_utilization -hierarchical -hierarchical_depth 100 -file $util_name.hier.txt
