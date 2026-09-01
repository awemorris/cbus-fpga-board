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

The `ws005p005` tests add:

- `tb_cbus_mailbox_alias_bridge`: all 16 aliases, low/high slices, WSTRB,
  upper-byte command no-op behavior, three-read diagnostic composition,
  up-to-three-write diagnostic acknowledge expansion, and first-error stop.
- `tb_axil_control_fabric_1x3`: AW-first, W-first and simultaneous writes,
  independent read routing, B/R backpressure, local DECERR gaps, and reset of
  a held split transaction.
- `tb_cbus_mailbox_alias_top`: asynchronous C-bus/AXI clocks through target,
  CDC, guard, decoder and mailbox/router; System CSR compatibility; H2C
  push/doorbell; logical pending; host polling; guard-fault event bit 6;
  nonselected High-Z; and physical IRQ remaining disconnected.

The check validates the canonical JSON schema, block/register uniqueness,
alignment, access/owner metadata, event destination masks and the relative
C-bus aliases. It then proves that the checked-in SystemVerilog, C and Rust
constant files exactly match the deterministic generator output.

The generated SystemVerilog package is compiled and exercised by Icarus
Verilog. The C header is compiled with 12 `_Static_assert` checks. A Rust
compiler is not required for this phase; the generated Rust file consists only
of `u32` constants and is still compared byte-for-byte with generator output.
