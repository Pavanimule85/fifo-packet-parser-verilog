# Packet Parser FSM + Synchronous FIFO (Verilog)

A byte-stream packet receiver: a parameterized synchronous FIFO feeds a 4-state FSM
that detects the start byte (0xA5), reads the length, accumulates an XOR checksum
over the payload, and flags each packet as valid or errored.

Packet format: `0xA5 | LEN | PAYLOAD[LEN] | CHK`, where `CHK = LEN ^ all payload bytes`.

## Files
- `sync_fifo.v`   - parameterized FIFO (WIDTH, DEPTH), full/empty flags, first-word fall-through
- `pkt_parser.v`  - FSM: IDLE -> LEN -> PAYLOAD -> CHK
- `tb_fifo.v`     - self-checking testbench: fill, overflow, drain order, underflow, simultaneous read/write
- `tb_pkt.v`      - self-checking testbench: good/bad checksum, garbage resync, zero-length, back-to-back packets with backpressure

## Run (Icarus Verilog + GTKWave)
    iverilog -g2012 -o fifo_sim sync_fifo.v tb_fifo.v && vvp fifo_sim
    iverilog -g2012 -o pkt_sim sync_fifo.v pkt_parser.v tb_pkt.v && vvp pkt_sim
    gtkwave pkt.vcd

Both testbenches print `ALL TESTS PASSED` when every check passes.

## Next steps
1. Open `pkt.vcd` in GTKWave and screenshot the FSM states and FIFO flags for the repo.
2. Synthesize in Vivado (free WebPACK) and note LUT/FF counts and timing.
3. Optional: run on a real board and add a UART front end.
