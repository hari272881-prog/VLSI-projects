# Ready/Valid Packet FIFO

An 8-entry, 32-bit packet FIFO in SystemVerilog. Each stored word carries a one-bit end-of-packet (`EOP`) marker. The FIFO uses ready/valid handshakes at both interfaces and a self-checking testbench.

## Interface

| Signal | Direction | Meaning |
| --- | --- | --- |
| `clk`, `rst` | Input | Clock and synchronous, active-high reset |
| `in_data[31:0]`, `in_eop` | Input | Word and its EOP marker from the producer |
| `in_valid` | Input | Producer is presenting a word |
| `in_ready` | Output | FIFO can accept the presented word |
| `out_data[31:0]`, `out_eop` | Output | Oldest stored word and its EOP marker |
| `out_valid` | Output | Output word is available |
| `out_ready` | Input | Consumer can accept the output word |

An input word is accepted on a rising edge when `in_valid && in_ready` is true. An output word is consumed on a rising edge when `out_valid && out_ready` is true. The producer supplies EOP; the FIFO stores it with the corresponding word. The producer must hold data and EOP stable while `in_valid` is high and `in_ready` is low.

The implementation uses a circular buffer, separate 3-bit read and write pointers, and a 4-bit occupancy count. It permits a read and write on the same edge when partially filled; the oldest word is read and the count stays unchanged. It does not bypass an input directly to an empty output. When full, `in_ready` remains low for the current edge even if a read also occurs on that edge.

## Files

- `packet_fifo.sv` — FIFO RTL.
- `tb_top.sv` — self-checking testbench.

## Verification

The testbench checks single-word and multiword packets, EOP ordering, full and empty status, a blocked ninth write, pointer wraparound, simultaneous input and output handshakes, reset with buffered data, and output stability under backpressure. A 100-word stress test randomizes consumer readiness and checks every received word and EOP against the expected sequence. A watchdog fails the run if progress stops.

Observed result with the included sources:

```text
Passed=138 Failed=0
```

### Run with Icarus Verilog

From this directory:

```sh
iverilog -g2012 -s tb_top -o sim.vvp packet_fifo.sv tb_top.sv
vvp sim.vvp
```

### Run with Vivado Simulator

Add `packet_fifo.sv` as a design source and `tb_top.sv` as a simulation source. Set `tb_top` as the simulation top, launch behavioral simulation, and run until `$finish` (`Run All` or `run -all`). Check the console for the pass/fail summary.
