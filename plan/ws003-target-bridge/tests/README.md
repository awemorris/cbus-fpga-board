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

## `tb_cbus_memory_target`

The standalone `ws003p004` memory-engine BFM checks the default-disabled instance continuously and exercises an enabled 24-bit aperture. It covers logical `SALE` upper-address capture and reset invalidation, inside/outside decode, address stability after cycle start, lower/upper/word lanes, back-to-back reads, `MWC+MWE` qualified writes, `MWC`-only and `MWE`-only suppression, `BE=00`, simultaneous memory strobes, I/O-memory conflicts, backend error, bounded timeout, early release, platform abort, reset, and recovery.

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

## `tb_cbus_memory_axil`

The `ws003p004` integration BFM runs the I/O and memory engines through the shared arbiter, dual-clock CDC/tag path, and AXI4-Lite bridge. It verifies natural 24-bit memory mapping into lower/upper AXI halfwords, byte strobes, independent AW/W backpressure, I/O-memory back-to-back traffic and overlap rejection, out-of-aperture suppression, AXI error conversion, timeout/stale-response quarantine, coherent reset, and preservation of the existing I/O System CSR path.

## `tb_axil_guard_timeout`

The standalone `ws003p003` test checks:

1. allowed access and independently arriving AW/W channels
2. local DECERR for both PC-98 host apertures without downstream handshake
3. first-fault retention and independent status clear
4. downstream SLVERR recording without quarantine
5. AR issue timeout with VALID/address retention
6. partial AW-only write timeout with WVALID/data/strobe retention
7. local DECERR for new requests while faulted
8. accepted-read response timeout, late R drain, subordinate reset, explicit fault clear, and recovery

## `tb_axil_system_csr`

The board-independent four-word System CSR subordinate checks product ID,
version/capability, byte-strobe scratch updates, synchronized C-bus/guard
status, independent AW/W arrival, B/R backpressure stability, RO `SLVERR`,
invalid/unaligned `DECERR`, and coherent reset.

## `tb_cbus_guarded_axil`

The end-to-end guard test uses unrelated 10 ns C-bus and 14 ns AXI clocks. It verifies normal ID/scratch access, an AXI response timeout that returns a C-bus backend error before the C-bus timeout, faulted local rejection without downstream leakage, subordinate reset plus fault clear, and coherent system-reset recovery.

## `tb_cbus_memory_top`

The common-IP integration test enables a 16-byte test aperture and maps it to the existing System CSR as a board-independent placeholder target. It proves logical `SALE` through `cbus_ip_top`, memory ID/scratch read/write, `MWC`-only non-commit, I/O compatibility, and passive address/command drive invariants. Production board shells still tie logical `SALE` low and add no physical endpoint.
