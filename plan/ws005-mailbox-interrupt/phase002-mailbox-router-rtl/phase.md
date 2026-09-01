# ws005p002: Mailbox FIFO / interrupt router standalone RTL

最終更新: 2026-09-01

WSID: `ws005`

Phase ID: `p002`

Combined ID: `ws005p002`

Status: planned; dependency satisfied by `ws005p001`

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

- [ ] Mailbox register/FIFOを実装する。
- [ ] Interrupt routerとevent routingを実装する。
- [ ] FIFOのempty/middle/full同時push/pop表を全網羅する。
- [ ] pending set/W1C/mask/resetの同時操作を全網羅する。
- [ ] doorbell coalescing、error分離clear、AXI backpressure/errorを検証する。
- [ ] 既存WS002/WS003回帰と定数生成照合を実行する。

## Completion conditions

- Contractの31 registerに対する正常/error/reset応答がBFMで一意に通る。
- 双方向FIFOがorderingを保ち、full/empty上でデータを破壊しない。
- setとack同時にsetが勝ち、mask中のeventがunmask後にIRQ activeになる。
- repeated doorbellはpendingを1に保ちcoalesced stickyで観測できる。
- AXI VALID payloadがREADYまで不変で、無限待ちとwarningがない。
- 既存HDL regressionとWS001/WS002 validatorがPASSする。

## Verification commands

Queue実行時にIcarus Verilog 12.0、SystemVerilog 2012の正確なコマンドとcheck数を追記する。

## Interruption and resume record

Not started. Cバスaliasや物理IRQの判断が必要になったら本Phaseを拡大せず、standalone RTLまでを検証して統合Phaseへ戻す。
