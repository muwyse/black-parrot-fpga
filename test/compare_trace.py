# SPDX-License-Identifier: BSD-3-Clause
#
# This script can be used to compare a commit trace from RTL simulation
# to an instruction trace from Dromajo.
#
# Run Dromajo with --trace=0 and capture stderr to a file using 2> dromajo.err
# Run RTL simulation with commit tracing enabled (default file is commit_0.trace)
#

import argparse

class TraceCompare:

  # constructor
  def __init__(self, dromajo_file, sim_file, boot_pc):

    # input parameters
    self.dromajo_file = dromajo_file
    self.sim_file = sim_file
    self.boot_pc = boot_pc

  def nextSim(self, f):
    l = f.readline()
    while l:
      ls = l.split()
      if int(ls[1], 16) >= self.boot_pc:
        return l
      l = f.readline()
    # end of file, return None
    return None

  def nextDromajo(self, f):
    l = f.readline()
    while l:
      ls = l.split()
      if not l.startswith('csr') and int(ls[2], 16) >= self.boot_pc:
        return l
      l = f.readline()
    # end of file, return None
    return None

  def proceed(self):
    print('Continue [y/n]: ', end='')
    s = input()
    if s is 'y':
      return True
    else:
      return False

  def compare(self, dl, sl):
    dl_vals = dl.strip().split()
    sl_vals = sl.strip().split()
    dl_pc = int(dl_vals[2], 16)
    sl_pc = int(sl_vals[1], 16)
    dl_insn = dl_vals[3][3:-1]
    sl_insn = sl_vals[2]
    reg_match = True
    val_match = True
    dl_reg = 0
    sl_reg = 0
    dl_val = 0
    sl_val = 0
    if len(dl_vals) > 4 and not 'exception' in dl:
      if len(dl_vals) == 6:
        dl_reg = int(dl_vals[4][1:], 10)
        dl_val = int(dl_vals[5], 16)
      else:
        dl_reg = int(dl_vals[5], 10)
        dl_val = int(dl_vals[6], 16)
    if len(sl_vals) > 4 and not 'trap' in sl:
      sl_reg = int(sl_vals[4], 16)
      sl_val = int(sl_vals[5], 16)
    pc_match = dl_pc == sl_pc
    if len(dl_vals) > 4:
      reg_match = dl_reg == sl_reg
      val_match = dl_val == sl_val
    else:
      reg_match = True
      val_match = True
    if not reg_match:
      print('reg mismatch')
    if not val_match:
      print('val mismatch')
    return (pc_match, reg_match, val_match)

  def run(self):
    insns = 0
    match = True
    with open(self.dromajo_file, 'r') as df, open(self.sim_file, 'r') as sf:
      while True:
        insns += 1
        dl = self.nextDromajo(df)
        sl = self.nextSim(sf)
        if not dl:
          print('INFO: reached end of Dromajo trace')
          break
        if not sl:
          print('INFO: reached end of sim trace')
          break
        match, reg_match, val_match = self.compare(dl, sl)
        if not match or not reg_match or not val_match:
          print('Mismatched lines')
          print('Instruction: {0}'.format(insns))
          print("Dromajo: " + dl.strip())
          print("Sim    : " + sl.strip())
        if not match and not self.proceed():
          break

    if match:
      print('Traces matched')
      print('Instructions: {0}'.format(insns))


#
#   main()
#
if __name__ == "__main__":

  parser = argparse.ArgumentParser()
  parser.add_argument('--dromajo', dest='dromajo_file', metavar='dromajo.err', help='instruction trace from Dromajo')
  parser.add_argument("--sim", dest='sim_file', metavar='sim.trace', help='commit trace from RTL simulation')
  parser.add_argument('--boot_pc', dest='boot_pc', type=int, default=0x80000000, help='The first PC to be executed after bootrom')

  args = parser.parse_args()

  runner = TraceCompare(args.dromajo_file, args.sim_file, args.boot_pc)
  runner.run()

