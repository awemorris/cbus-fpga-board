# WS003 simulations

Simulator: Icarus Verilog 12.0、SystemVerilog 2012 mode。

Run from repository root:

```sh
plan/ws003-target-bridge/tests/run_iverilog.sh
```

The tests are deterministic and report `SEED=1` where a BFM is used. Compiled simulations and VCD files are written below `plan/ws003-target-bridge/temp/iverilog/` and are intentionally ignored by Git.

## `tb_cbus_target_mvp`

The original `ws003p001` same-clock target-engine regression covers:

1. reset and `platform_ready` High-Z gate
2. 16-bit ID read without wait
3. even/odd 8-bit lane reads
4. 16-bit and byte-enable scratch writes/readback
5. nonselected address and invalid lane suppression
6. read-only backend error
7. IORDY wait, bounded timeout, fallback read data
8. active-cycle `platform_ready` abort
9. active-cycle reset abort
10. post-reset recovery

The continuous monitor rejects host/target data contention, X on a driven data bus, target data drive during write, and any output request during reset/not-ready.

For the 386-or-later target baseline, the BFM also checks no-wait read response within 239 ns, IORDY assertion within 80 ns, IORDY Low width from 40 ns through 7 us, and at least 5 ns of read-data hold after the external strobe rises.

## `tb_async_fifo`

The generic depth-four FIFO is exercised with unrelated 10 ns and 14 ns clocks. The test fills and drains the FIFO, checks full/empty behavior, wraps pointers through 48 ordered transfers with backpressure, and applies a coherent reset.

## `tb_cbus_axil_bridge`

The `ws003p002` integration test connects the tri-state C-bus BFM through two asynchronous FIFOs and the AXI4-Lite Manager bridge to a self-checking subordinate model. It checks:

1. C-bus offset to 32-bit AXI register address mapping
2. 16-bit, low-byte, and high-byte `WDATA/WSTRB`
3. independent AW, W, and AR backpressure
4. delayed B/R responses and IORDY wait
5. AXI `SLVERR` conversion to C-bus error data and sticky status
6. C-bus timeout followed by tagged stale-response discard and recovery
7. coherent reset, platform output gate, and post-reset recovery

The C-bus and AXI models use unrelated 10 ns and 14 ns clocks. Continuous checks retain the contention, driven-X, write-drive, and reset/not-ready output safety rules.
