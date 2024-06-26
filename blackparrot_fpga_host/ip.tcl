# SPDX-License-Identifier: BSD-3-Clause
#
# ip.tcl
#
# Set IPX properties for BP FPGA Host block
#

# addressing and memory information
ipx::remove_all_memory_map [ipx::current_core]
ipx::add_memory_map s_axi [ipx::current_core]
set_property slave_memory_map_ref s_axi [ipx::get_bus_interfaces s_axi -of_objects [ipx::current_core]]
ipx::add_memory_map s_axil [ipx::current_core]
set_property slave_memory_map_ref s_axil [ipx::get_bus_interfaces s_axil -of_objects [ipx::current_core]]

# S_AXI
ipx::add_address_block mem [ipx::get_memory_maps s_axi -of_objects [ipx::current_core]]
set_property usage memory [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axi -of_objects [ipx::current_core]]]
set_property access read-write [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axi -of_objects [ipx::current_core]]]
set_property range_dependency {pow(2,(spirit::decode(id('MODELPARAM_VALUE.S_AXI_ADDR_WIDTH')) - 1) + 1)} [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axi -of_objects [ipx::current_core]]]
set_property range_resolve_type dependent [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axi -of_objects [ipx::current_core]]]
set_property width_dependency {(spirit::decode(id('MODELPARAM_VALUE.S_AXI_DATA_WIDTH')) - 1) + 1} [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axi -of_objects [ipx::current_core]]]
set_property width_resolve_type dependent [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axi -of_objects [ipx::current_core]]]

# S_AXIL
ipx::add_address_block mem [ipx::get_memory_maps s_axil -of_objects [ipx::current_core]]
set_property usage memory [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axil -of_objects [ipx::current_core]]]
set_property access read-write [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axil -of_objects [ipx::current_core]]]
set_property range_dependency {pow(2,(spirit::decode(id('MODELPARAM_VALUE.S_AXIL_ADDR_WIDTH')) - 1) + 1)} [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axil -of_objects [ipx::current_core]]]
set_property range_resolve_type dependent [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axil -of_objects [ipx::current_core]]]
set_property width_dependency {(spirit::decode(id('MODELPARAM_VALUE.S_AXIL_DATA_WIDTH')) - 1) + 1} [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axil -of_objects [ipx::current_core]]]
set_property width_resolve_type dependent [ipx::get_address_blocks mem -of_objects [ipx::get_memory_maps s_axil -of_objects [ipx::current_core]]]

# clocks
#set_property ipi_drc {ignore_freq_hz true} [ipx::current_core]
ipx::add_bus_parameter FREQ_TOLERANCE_HZ [ipx::get_bus_interfaces m_axi_aclk -of_objects [ipx::current_core]]
set_property value -1 [ipx::get_bus_parameters FREQ_TOLERANCE_HZ -of_objects [ipx::get_bus_interfaces m_axi_aclk -of_objects [ipx::current_core]]]
ipx::add_bus_parameter FREQ_TOLERANCE_HZ [ipx::get_bus_interfaces s_axi_aclk -of_objects [ipx::current_core]]
set_property value -1 [ipx::get_bus_parameters FREQ_TOLERANCE_HZ -of_objects [ipx::get_bus_interfaces s_axi_aclk -of_objects [ipx::current_core]]]
ipx::add_bus_parameter FREQ_TOLERANCE_HZ [ipx::get_bus_interfaces s_axil_aclk -of_objects [ipx::current_core]]
set_property value -1 [ipx::get_bus_parameters FREQ_TOLERANCE_HZ -of_objects [ipx::get_bus_interfaces s_axil_aclk -of_objects [ipx::current_core]]]

