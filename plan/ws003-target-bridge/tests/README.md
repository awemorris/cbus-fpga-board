# ws003p001 simulation

Simulator: Icarus Verilog 12.0、SystemVerilog 2012 mode。

Run from repository root:

```sh
plan/ws003-target-bridge/tests/run_iverilog.sh
```

The test is deterministic and reports `SEED=1`. Build output and `tb_cbus_target_mvp.vcd` are written below `plan/ws003-target-bridge/temp/iverilog/` and are intentionally ignored by Git.

Self-checking cases:

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
