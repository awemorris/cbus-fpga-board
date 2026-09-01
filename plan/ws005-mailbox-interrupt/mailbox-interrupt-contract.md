# Mailbox / doorbell / interrupt contract

更新日: 2026-09-01

対象: `ws005p001`

ABI: version 1

機械可読なレジスタ番地と定数の正本は
[`mailbox-register-map.json`](mailbox-register-map.json)とする。本書はレジスタの意味、状態遷移、同時操作の優先順位を定義する。

## 1. 設計境界

- H2C (host-to-control)とC2H (control-to-host)に、それぞれ8 entry、32-bitのFIFOを持つ。
- `control`は将来のRISC-Vに限定せず、CPU、debug manager、または試験BFMが担うFPGAローカル制御面を意味する。
- FIFO pushとdoorbellは別操作である。通常の順序は、data pushのAXI/Cバス完了後にdoorbell setとする。
- Doorbellは1-bit pendingへcoalesceし、回数counterではない。データ数はFIFO occupancyで管理する。
- pendingはmaskに関係なく保持し、受信側だけがW1C acknowledgeする。
- 物理CバスI/O baseとIRQ番号は未決定である。このABIはIRQ未割当でもpollingで全操作できる。

## 2. AXI4-Lite address space

| Block | Range | Purpose |
| --- | --- | --- |
| Interrupt router | `0x1000_2000-0x1000_2fff` | CPU/host別pending、mask、ack、active。 |
| Mailbox | `0x1000_3000-0x1000_3fff` | H2C/C2H FIFO、status、doorbell。 |

全registerは32-bit、4-byte alignedである。未実装offsetとunaligned accessは`DECERR`、RO writeまたは不正なstrobe/commandは`SLVERR`とする。AXI4-Liteにmanager identityはないため、owner制限はCバスaliasと将来のinterconnect/firewallが許可registerだけを露出して実施する。subordinate単体はAXI managerの種類を推測しない。

Access表記:

- `RO`: read-only。
- `RW`: byte strobeごとに更新する。
- `W1C`: write dataが1のbitをclearする。
- `W1S`: write dataが1のbitをsetする。
- `W1P`: bit 0へ1を書くと一回のpulse operationを行う。
- `PUSH32`: `WSTRB=4'b1111`のwrite一回で1 entryをpushする。それ以外は`SLVERR`でpushしない。

## 3. Interrupt router registers

Base: `0x1000_2000`

| Offset | Name | Access | Reset | Owner / meaning |
| ---: | --- | --- | ---: | --- |
| `0x000` | `ID` | RO | `0x4952_0001` | `IR`, ABI v1。 |
| `0x004` | `CAP` | RO | `0x0020_0001` | 32 sources、ABI v1。 |
| `0x010` | `CPU_PENDING` | RO | `0` | CPU/control向けlatched pending。 |
| `0x014` | `CPU_MASK` | RW | `0` | controlが更新。1=IRQ line enable。 |
| `0x018` | `CPU_ACK` | W1C | `0` | controlが`CPU_PENDING`をclear。 |
| `0x01c` | `CPU_ACTIVE` | RO | `0` | `CPU_PENDING & CPU_MASK`。 |
| `0x020` | `HOST_PENDING` | RO | `0` | host向けlatched pending。 |
| `0x024` | `HOST_MASK` | RW | `0` | hostが更新。1=CバスIRQ要求enable。 |
| `0x028` | `HOST_ACK` | W1C | `0` | hostが`HOST_PENDING`をclear。 |
| `0x02c` | `HOST_ACTIVE` | RO | `0` | `HOST_PENDING & HOST_MASK`。 |

Reset時は両maskが0のため、CPU IRQもCバスIRQ要求もdeassertedで起動する。物理IRQ出力のactive polarity、open-drain相当回路、選択番号はWS001/WS008で別に決定する。

## 4. Mailbox registers

Base: `0x1000_3000`

| Offset | Name | Access | Reset | Owner / side effect |
| ---: | --- | --- | ---: | --- |
| `0x000` | `ID` | RO | `0x4d42_0001` | `MB`, ABI v1。 |
| `0x004` | `CAP` | RO | `0x0820_0001` | depth 8、width 32、ABI v1。 |
| `0x010` | `H2C_HOST_LO` | RW | `0` | host staging bits 15:0。 |
| `0x014` | `H2C_HOST_HI` | RW | `0` | host staging bits 31:16。 |
| `0x018` | `H2C_HOST_PUSH` | W1P | `0` | staging 32-bitをH2Cへsnapshot/push。 |
| `0x01c` | `H2C_CPU_DATA` | RO | `0` | H2C headをpeek。popしない。 |
| `0x020` | `H2C_CPU_POP` | W1P | `0` | H2C headをpop。 |
| `0x024` | `H2C_STATUS` | RO | `0x0000_0100` | occupancy/empty/full/error sticky。 |
| `0x028` | `H2C_HOST_ERR_ACK` | W1C | `0` | hostがoverflow bit 16だけclear。 |
| `0x02c` | `H2C_CPU_ERR_ACK` | W1C | `0` | controlがunderflow bit 17だけclear。 |
| `0x030` | `C2H_CPU_PUSH_DATA` | PUSH32 | `0` | controlがwrite dataをC2Hへpush。 |
| `0x034` | `C2H_HOST_LO` | RO | `0` | C2H head bits 15:0をpeek。 |
| `0x038` | `C2H_HOST_HI` | RO | `0` | 同じhead bits 31:16をpeek。 |
| `0x03c` | `C2H_HOST_POP` | W1P | `0` | hostがC2H headをpop。 |
| `0x040` | `C2H_STATUS` | RO | `0x0000_0100` | occupancy/empty/full/error sticky。 |
| `0x044` | `C2H_CPU_ERR_ACK` | W1C | `0` | controlがoverflow bit 16だけclear。 |
| `0x048` | `C2H_HOST_ERR_ACK` | W1C | `0` | hostがunderflow bit 17だけclear。 |
| `0x050` | `H2C_DOORBELL_SET` | W1S | `0` | hostがbit 0をsetしCPU pendingを発生。 |
| `0x054` | `C2H_DOORBELL_SET` | W1S | `0` | controlがbit 1をsetしhost pendingを発生。 |
| `0x058` | `DOORBELL_STATUS` | RO | `0` | bits 1:0 pending、bits 17:16 coalesced sticky。 |
| `0x05c` | `DOORBELL_COALESCED_ACK` | W1C | `0` | CPUはbit16、hostはbit17だけclear。 |

H2C/C2H `STATUS`:

| Bits | Meaning |
| --- | --- |
| `3:0` | occupancy `0..8`。 |
| `8` | empty level。 |
| `9` | full level。 |
| `16` | overflow sticky。full時pushを拒否するとset。 |
| `17` | underflow sticky。empty時data readまたはpopでset。 |
| others | reserved zero。 |

H2C stagingはpush後も保持する。再度pushすれば同じ値を新しいentryとして格納する。C2HのLO/HI readは同じheadから読まれ、明示的POPまで不変である。これによりCバス8/16-bit readの途中でheadが変わらない。

## 5. Event sources and service priority

Priorityは複数pending時の推奨software service順で、0が最優先である。全sourceは独立にlatchされるため、優先度が低いsourceも失われない。

| Bit | Event | Destination | Priority | Set condition |
| ---: | --- | --- | ---: | --- |
| 0 | `H2C_DOORBELL` | CPU | 0 | host doorbell set。 |
| 1 | `C2H_DOORBELL` | host | 0 | control doorbell set。 |
| 2 | `H2C_OVERFLOW` | CPU | 1 | H2C full push拒否。 |
| 3 | `H2C_UNDERFLOW` | CPU | 1 | H2C empty read/pop。 |
| 4 | `C2H_OVERFLOW` | CPU | 1 | C2H full push拒否。 |
| 5 | `C2H_UNDERFLOW` | CPU | 1 | C2H empty read/pop。 |
| 6 | `GUARD_FAULT` | CPU | 0 | AXI guard fault。 |
| 7 | reserved | - | - | 0を保つ。 |
| 8 | `DMA_DONE` | CPU | 3 | 将来DMA completion。 |
| 9 | `DMA_ERROR` | CPU | 1 | 将来DMA error。 |
| 10:15 | reserved | - | - | 0を保つ。 |
| 16:23 | `USER_IRQ0..7` | CPU | 4 | 将来user IP event。 |
| 24:31 | reserved | - | - | 0を保つ。 |

User sourceの正式名は`USER_IRQ0`、`USER_IRQ1`、`USER_IRQ2`、`USER_IRQ3`、`USER_IRQ4`、`USER_IRQ5`、`USER_IRQ6`、`USER_IRQ7`である。

DMA/user IPからhostへ直接IRQを出さず、初版はcontrolが状態を処理した後にC2H mailbox/doorbellでhostへ通知する。これにより物理CバスIRQを一本の管理可能なsourceへ限定する。

## 6. State transition and collision rules

### FIFO decision table

`push_req`/`pop_req`は同じFIFOに同じclockでcommitされた操作を示す。

| Pre-state | Requests | Accepted operations | Next occupancy | Sticky result |
| --- | --- | --- | --- | --- |
| empty | none | none | 0 | unchanged |
| empty | push | push | 1 | unchanged |
| empty | pop | none | 0 | underflow set |
| empty | push + pop | push only; no fall-through | 1 | underflow set |
| `1..7` | push | push | `+1` | unchanged |
| `1..7` | pop | pop | `-1` | unchanged |
| `1..7` | push + pop | both | unchanged | unchanged |
| full | push | none | 8 | overflow set |
| full | pop | pop | 7 | unchanged |
| full | push + pop | both; old head pops, new tail pushes | 8 | unchanged |

ResetはFIFO content、pointer、occupancy、staging、error stickyをclearし、empty=1/full=0とする。Resetと同時のAXI/Cバス操作はcommitせず、resetが勝つ。

### Pending / mask / acknowledge decision table

| Condition in one router clock | Next pending | Other result |
| --- | --- | --- |
| no set, no W1C | unchanged | - |
| no set, W1C=1 | 0 | - |
| set, W1C=0 | 1 | - |
| set, W1C=1 | 1 | set wins |
| mask changes | unchanged | active recomputes as pending & new mask |
| reset with any operation | 0 | mask=0, IRQ inactive |

Doorbell set時に該当pendingのpre-stateが1ならcoalesced stickyをsetする。pending=0でsetとW1Cが同時ならpending=1とするがcoalescedはsetしない。mask=0中でもpending/coalesced/errorは記録し、後にmask=1にすればactive IRQとなる。

Mailbox error stickyとrouter pendingは別にclearする。これにより診断記録を残したままIRQ処理を終える、またはその逆の操作ができる。

## 7. C-bus relative alias aperture

物理baseを`CBUS_MBX_IO_BASE`と呼び、初版は`base+0x00..+0x1f`の32-byte範囲を予約する。以下は16-bit word offsetで、8-bit even/odd laneも使用できる。

| Cバスoffset | Alias | AXI target / slice | Access |
| ---: | --- | --- | --- |
| `+0x00` | `H2C_LO` | `MBX.H2C_HOST_LO[15:0]` | RW |
| `+0x02` | `H2C_HI` | `MBX.H2C_HOST_HI[15:0]` | RW |
| `+0x04` | `H2C_PUSH` | `MBX.H2C_HOST_PUSH[15:0]` | W1P |
| `+0x06` | `H2C_DOORBELL_SET` | `MBX.H2C_DOORBELL_SET[15:0]` | W1S |
| `+0x08` | `H2C_STATUS_LO` | `MBX.H2C_STATUS[15:0]` | RO |
| `+0x0a` | `H2C_STATUS_HI` | `MBX.H2C_STATUS[31:16]` | RO |
| `+0x0c` | `C2H_LO` | `MBX.C2H_HOST_LO[15:0]` | RO |
| `+0x0e` | `C2H_HI` | `MBX.C2H_HOST_HI[15:0]` | RO |
| `+0x10` | `C2H_POP` | `MBX.C2H_HOST_POP[15:0]` | W1P |
| `+0x12` | `C2H_STATUS_LO` | `MBX.C2H_STATUS[15:0]` | RO |
| `+0x14` | `C2H_STATUS_HI` | `MBX.C2H_STATUS[31:16]` | RO |
| `+0x16` | `HOST_PENDING` | `INTR.HOST_PENDING[15:0]` | RO |
| `+0x18` | `HOST_MASK` | `INTR.HOST_MASK[15:0]` | RW |
| `+0x1a` | `HOST_ACK` | `INTR.HOST_ACK[15:0]` | W1C |
| `+0x1c` | `HOST_DIAG_STATUS` | bit0=H2C overflow, bit1=C2H underflow, bit2=C2H doorbell coalesced | RO |
| `+0x1e` | `HOST_DIAG_ACK` | bits 2:0を対応するstickyへ変換 | W1C |

`HOST_DIAG_ACK`はCバスエイリアスだけの複合commandで、AXI側ではbit 0を`H2C_HOST_ERR_ACK[16]`、bit 1を`C2H_HOST_ERR_ACK[17]`、bit 2を`DOORBELL_COALESCED_ACK[17]`へ変換する。物理baseとdecode/maskはポート競合調査後に固定する。

## 8. Ordering and clock-domain policy

- Producerはpush responseを確認してからdoorbellを書く。AXI interconnectはdifferent manager間の順序を仮定しない。
- 同一AXI managerのwrite response順と各registerのcommit順は保つ。
- Cバス要求は既存CDC/AXI managerが一件ずつcommitする。
- 非同期event sourceはinterrupt router内へ直接入れず、source側sticky levelの同期化またはreq/ack handshakeを使う。
- FIFOを真に異なるclock domainから直接使う場合はGray pointer asynchronous FIFOとし、本書の同時操作規則を境界で保つ。

## 9. Shared constants and change control

`mailbox-register-map.json`から次を生成する。

- `rtl/include/cbus_mailbox_regs_pkg.sv`
- `sw/include/cbus_mailbox_regs.h`
- `sw/rust/cbus_mailbox_regs.rs`

照合コマンド:

```sh
python3 plan/ws005-mailbox-interrupt/tests/generate_mailbox_constants.py
```

意図的にABIを変更する場合だけJSONの`abi_version`を上げ、`--write`で三言語の生成物を同時更新する。生成物の手編集は禁止する。

## 10. Deferred physical decisions

- Cバスmailbox I/O baseとdecode mask。
- CバスIRQ番号、jumper/DIP/softwareの選択方式。
- IRQ共有可否、電気極性、OE、reset/configuration中High-Z。
- 実CPUとfirmware ISR。RISC-Vコア選定は後回しのままである。
- AXI interconnect、standalone mailbox/router RTLと`cbus_ip_top`の統合、Cバスalias bridgeの実装。standalone RTL自体は`ws005p002`で完了済み。
