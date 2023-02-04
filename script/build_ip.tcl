# SPDX-License-Identifier: BSD-3-Clause
#
# build_ip.tcl
#
# Package RTL as an IP block
#

# arguments from environment
# these are expected to be set by a Makefile prior to invoking this script
set ip_name         $::env(IP_NAME)
set ip_dir          $::env(IP_DIR)
set ip_top          $::env(IP_TOP)
set ip_flist        $::env(IP_FLIST)
set ip_property_tcl $::env(IP_PROPERTY_TCL)

set ip_vendor       $::env(IP_VENDOR)
set ip_vendor_name  $::env(IP_VENDOR_NAME)
set ip_library      $::env(IP_LIBRARY)
set ip_taxonomy     $::env(IP_TAXONOMY)
set ip_version      $::env(IP_VERSION)

set part            $::env(PART)
set project_dir     $::env(PROJECT_DIR)
set project_name    $::env(PROJECT_NAME)
set parse_flist_tcl $::env(PARSE_FLIST_TCL)

# parse IP flist
source ${parse_flist_tcl}
set vlist [parse_flist ${ip_flist}]
set vsources_list  [lindex $vlist 0]
set vincludes_list [lindex $vlist 1]
set vdefines_list  [lindex $vlist 2]

# create project
create_project -force -part ${part} ${project_name} ${project_dir}

if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# add files
add_files -norecurse ${vsources_list}
set_property file_type SystemVerilog [get_files ${vsources_list}]
set_property include_dirs ${vincludes_list} [current_fileset]
set_property verilog_define ${vdefines_list} [current_fileset]
set_property top ${ip_top} [current_fileset]
update_compile_order -fileset sources_1

# set IP packaging properties
ipx::package_project -root_dir ${ip_dir} -vendor ${ip_vendor} -library ${ip_library} -taxonomy ${ip_taxonomy} -import_files -set_current false
ipx::unload_core ${ip_dir}/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory ${ip_dir} ${ip_dir}/component.xml
update_compile_order -fileset sources_1
set_property vendor ${ip_vendor} [ipx::current_core]
set_property library ${ip_library} [ipx::current_core]
set_property name ${ip_name} [ipx::current_core]
set_property version ${ip_version} [ipx::current_core]
set_property display_name ${ip_name} [ipx::current_core]
set_property description ${ip_name} [ipx::current_core]
set_property vendor_display_name ${ip_vendor_name} [ipx::current_core]

# set IP-specific properties
source ${ip_property_tcl}

# finish IP packaging
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::move_temp_component_back -component [ipx::current_core]
close_project -delete
set_property ip_repo_paths ${ip_dir} [current_project]
update_ip_catalog

