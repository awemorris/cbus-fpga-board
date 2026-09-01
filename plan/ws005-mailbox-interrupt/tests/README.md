# WS005 verification

Run from the repository root:

```sh
plan/ws005-mailbox-interrupt/tests/run_iverilog.sh
plan/ws005-mailbox-interrupt/tests/run_contract_checks.sh
```

`run_iverilog.sh` exercises the synchronous FIFO decision table and the
standalone mailbox/interrupt subsystem. It covers both AXI4-Lite subordinate
ports, all 31 ABI registers, FIFO ordering and boundary errors, interrupt
mask/pending/W1C set-wins behavior, doorbell coalescing, response
backpressure, decode errors and coherent reset.

The check validates the canonical JSON schema, block/register uniqueness,
alignment, access/owner metadata, event destination masks and the relative
C-bus aliases. It then proves that the checked-in SystemVerilog, C and Rust
constant files exactly match the deterministic generator output.

The generated SystemVerilog package is compiled and exercised by Icarus
Verilog. The C header is compiled with 12 `_Static_assert` checks. A Rust
compiler is not required for this phase; the generated Rust file consists only
of `u32` constants and is still compared byte-for-byte with generator output.
