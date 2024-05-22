# Simulation of BlackParrot and BlackParrot FPGA Host

Makefile commands:

```
make clean # clean the simulation folder
make lint.[verilator|vcs] CFG=<cfg>
make sim_prep PROG=<program> SUITE=<suite>
make build[_dump].[verilator|vcs] sim[_dump].[verilator|vcs] [CFG=<cfg>] [COSIM_P=0] [COMMIT_TRACE_P=1]
```

Dromajo cosimulation is enabled by default but can be turned off. Core commit tracing
can be optionally enabled.

NBF options, used with `make sim_prep` target. Importantly, the number of cpus
specified should match the config used in simulation.

```
NBF_NCPUS=<ncpus>
NBF_MEM_SIZE=<dram size>

```

