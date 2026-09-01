# ws005p002: Mailbox FIFO / interrupt router standalone RTL

最終更新: 2026-09-01

WSID: `ws005`

Phase ID: `p002`

Combined ID: `ws005p002`

Status: completed

Parent: [WS005](../ws.md)

## Objective

ABI v1の双方向FIFO、doorbell、error sticky、CPU/host interrupt pending/mask/W1Cを、boardとCPUコアに依存しないstandalone AXI4-Lite subordinate RTLとして実装する。

## Source contract

- [Mailbox / interrupt contract](../mailbox-interrupt-contract.md)
- [Canonical register map](../mailbox-register-map.json)
- `rtl/include/cbus_mailbox_regs_pkg.sv`

ABIの番地、reset、所有者、同時操作規則を変更するなら、RTLで吸収せず`ws005p001`の契約改定として扱う。

## Scope

- depth 8、width 32のH2C/C2H FIFO。
- H2C staging/push/peek/pop、C2H push/peek/pop。
- occupancy、empty/full、overflow/underflow sticky。
- H2C/C2H doorbell set pulse、pending mirror、coalesced sticky。
- 32-source CPU/host interrupt router、mask、W1C ack、set-wins collision。
- AXI4-Lite AW/W独立受理、WSTRB、B/R backpressure、SLVERR/DECERR。
- Mailbox eventをrouterのABI v1 source bitへ接続するstandalone subsystem。
- standalone AXI BFMとdirect event BFM。

## Excluded

- `cbus_ip_top`統合、AXI interconnect、Cバスalias decoder。
- 物理CバスI/O baseとIRQ番号、IRQ OE/極性。
- RISC-Vコア、firmware、PC-98診断プログラム。
- DMA/user IP本体、監視write-event FIFO。
- Gowin合成、回路図、PCB、実機。

## Implementation policy

- Mailboxとinterrupt routerを別moduleにし、一方のfault/timeoutが他方のAXI responseを保持しない構造にする。
- FIFOは現Phaseでは同一AXI clockで動作させる。異なるclock domainを後で追加する場合は既存`async_fifo`または明示的handshakeを使う。
- event inputはclock同期の一サイクルset pulseまたは事前にlatchされたlevelとし、非同期入力はmodule内で推測しない。
- RouterはCPU/hostの許可source mask外を0に強制する。
- AXI subordinateはmanager identityを判定しない。ownerアクセス制御は後のCバスalias/interconnect統合で行う。

## Work packages

- [x] Mailbox register/FIFOを実装する。
- [x] Interrupt routerとevent routingを実装する。
- [x] FIFOのempty/middle/full同時push/pop表を全網羅する。
- [x] pending set/W1C/mask/resetの同時操作を全網羅する。
- [x] doorbell coalescing、error分離clear、AXI backpressure/errorを検証する。
- [x] 既存WS002/WS003回帰と定数生成照合を実行する。

## Completion conditions

- Contractの31 registerに対する正常/error/reset応答がBFMで一意に通る。
- 双方向FIFOがorderingを保ち、full/empty上でデータを破壊しない。
- setとack同時にsetが勝ち、mask中のeventがunmask後にIRQ activeになる。
- repeated doorbellはpendingを1に保ちcoalesced stickyで観測できる。
- AXI VALID payloadがREADYまで不変で、無限待ちとwarningがない。
- 既存HDL regressionとWS001/WS002 validatorがPASSする。

## Verification commands

Repository rootから実行する。

```sh
plan/ws005-mailbox-interrupt/tests/run_iverilog.sh
plan/ws005-mailbox-interrupt/tests/run_contract_checks.sh
plan/ws003-target-bridge/tests/run_iverilog.sh
plan/ws002-fpga-platform/tests/run_iverilog.sh
python3 plan/ws001-cbus-contract/tests/validate_signal_matrix.py
python3 plan/ws001-cbus-contract/tests/validate_platform_maps.py
python3 plan/ws002-fpga-platform/tests/validate_pinouts.py
python3 plan/ws002-fpga-platform/tests/validate_portable_top.py
```

Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`で次をPASSした。

- `tb_mailbox_sync_fifo`: 25 checks。
- `tb_mailbox_interrupt_subsystem`: 91 checks。
- ABI/schema/generator: 31 registers、17 events、16 aliases。SV/C定数は各12 checks。
- 既存WS003: 656 checks。既存WS002: 3377 checks。
- WS001 signal/platform mapping、WS002 pinout/constraint/portable-top validator: PASS。

新規HDLは116 checks、既存を含むHDL合計は4149 checksである。warningと無限待ちはない。

## Interruption and resume record

Completed in `Q20260901-012`。

- `mailbox_sync_fifo`がFIFO決定表を封じ込め、`axil_mailbox`と`axil_interrupt_router`を別module/別AXI subordinate portにした。
- `mailbox_interrupt_subsystem`はmailbox eventと外部同期eventをrouterへ接続する。共通IPのAXI interconnectは現Phaseに含めない。
- RTLは生成済みSystemVerilog packageのbase、ID/CAP、valid-source mask、event maskを参照する。ABIの独自改定はない。
- 物理IRQ、Cバスalias、RISC-Vの人間判断は必要にならず、後続Phaseの境界を維持した。
