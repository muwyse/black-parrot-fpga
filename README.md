# BlackParrot on VCU128

### PC Host setup
* clone `black-parrot-phd` and submodules `dma\_ip\_drivers` and `black-parrot-fpga (fpga)`
* compile nbf program

### Design instructions
* compile design
* build software and copy `.riscv` files to directory with nbf program

### Programming the FPGA
* On PC Host
  * `lspci -vvv` to verify device is found
  * if not found, `poweroff` command from PC Host
  * wait for at least one minute
  * `sudo python short_press.py` from Raspberry Pi to power on host
* copy bitstream to PC Host
* program bitstream to FPGA using `program_fpga.tcl` script
* reboot PC host with `sudo reboot`
* login to PC host

### Running experiments (repeat to re-run with different programs)
* reset VCU128 from Raspberry Pi with `sudo python reset_vcu128.py`
* use nbf program and Makefile to load program to FPGA
* wait for FPGA to finish
  * if running Linux on FPGA, `poweroff` or `CTRL+c` to stop execution
* reset VCU128 from Raspberry Pi with `sudo python reset_vcu128.py`
