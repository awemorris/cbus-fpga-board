# ws005p004: Cバスrange-write event frontend

最終更新: 2026-09-01

WSID: `ws005`

Phase ID: `p004`

Combined ID: `ws005p004`

Status: planned after ws004p002

Parent: [WS005](../ws.md)

## User requirement

CバスのI/Oまたはmemory空間にある設定可能な範囲へのwriteを、RISC-Vコア外のfrontendがcaptureし、CPUへexternal interruptとして通知できるようにする。CPU core portへCバス固有信号やevent IDを追加しない。

## Objective

正規化済みCバスwrite transactionを設定可能なrangeで選択し、address/data/lane/spaceをevent FIFOへ保存する。AXI4-Lite CSRからrange設定とFIFO読出しを行い、既存32-source interrupt routerを介して`irq_external_i`へlevel通知するboard-independent frontendを実装・検証する。

## Dependencies

- `ws003p004`: I/O/memory共通の`space, addr24, write, data16, be2, tag` request契約。
- `ws005p005`: mailbox/routerの共通IP統合とAXI4-Lite control fabric。
- `ws004p001`: user coreの`irq_external_i` level入力と単一AXI4 Manager。
- `ws004p002`: CPU AXI4から`0x1000_4000-0x1000_4fff`へ到達するsingle-beat AXI4-to-AXI4-Lite routeと、Cバスから同領域を拒否するmanager policy。
- `ws005p001/p002`: pending/mask/W1C、set-wins、CPU external IRQ集約。

## Architecture boundary

```text
C-bus I/O/memory target engine
       |
       +-- normalized accepted-write tap
                    |
                    v
          cbus_write_event_frontend
            4 range comparators
            8-entry event FIFO
            overflow/coalesced status
            AXI4-Lite CPU CSR
                    |
             event source bit 7
                    v
          interrupt router cpu_irq_active
                    |
             core irq_external_i
```

frontendはCバス物理pinを見ず、Cバスclock側で一度だけacceptされた正規化requestを入力にする。frontendのfull/backpressureで元のCバスtransactionを止めない。FIFO full時はeventをdropし、overflow stickyとIRQを必ず残す。

## Match slots

初期実装は4 slot。各slotはAXI4-Liteから次を設定する。

| Field | Width | Meaning |
| --- | ---: | --- |
| `ENABLE` | 1 | 1でmatchを有効化。reset=0。 |
| `SPACE` | 1 | 0=CバスI/O、1=Cバスmemory。 |
| `BASE` | 24 | inclusive start address。I/Oは上位8 bitを0にする。 |
| `LIMIT` | 24 | inclusive end address。`BASE <= LIMIT`を必須とする。 |
| `LANE_MASK` | 2 | capture対象byte lane。0はslot disabled相当の設定error。 |

match条件は`ENABLE && space一致 && BASE <= addr <= LIMIT && |(be & LANE_MASK)`とする。複数slotが同時matchした場合は一eventだけenqueueし、lowest slot番号をrecordする。設定errorはstatusに残し、そのslotをmatchさせない。

rangeは任意のinclusive base/limitとし、power-of-two alignmentを要求しない。実CバスI/O/memory resource割当は別の人間判断であり、reset後は全slot disabledとする。

## Capture point and event semantics

- `write=1`かつnormalized requestが`valid && ready`で受理されたclock edgeを一write eventとする。
- read、nonselected、invalid lane、aborted-before-accept、reset中requestはcaptureしない。
- eventは「Cバスfrontendがwrite cycleを受理した」ことを示す。後段AXI targetのcommit成功を意味しない。
- original request/tagと同じcycleからeventを生成し、一transactionを二重captureしない。
- Cバスresponse、IORDY、guard、target routingへbackpressureや追加side effectを与えない。
- softwareがevent payloadだけで処理可能なようにaddress/data/lane/spaceを保存する。後段registerを直ちに読む場合のorderingは別targetのcommit完了を確認する必要がある。

Event record論理field:

| Field | Width | Meaning |
| --- | ---: | --- |
| `SEQ` | 8 | enqueueごとにincrement、wrap可。dropでもincrementして欠落を観測可能にする。 |
| `SLOT` | 2 | lowest matching slot。 |
| `SPACE` | 1 | I/O=0、memory=1。 |
| `ADDR` | 24 | Cバスbyte address。 |
| `BE` | 2 | lower/upper byte enable。 |
| `WDATA` | 16 | Cバスwrite data。 |

内部FIFOは8 entry。AXI4-Lite readはhead snapshotを明示POPまで保持し、複数register readの途中で変えない。

## AXI4-Lite CSR proposal

Master mapと`ws004p002`で予約した`0x1000_4000-0x1000_4fff`を使用し、Phase実行時にmachine-readable mapへ確定登録する。

Register groups:

- `ID_VERSION`, `CAPABILITY`, `CONTROL`, `STATUS`。
- slot 0〜3の`BASE`, `LIMIT`, `CONFIG`。
- `EVENT_ADDR`, `EVENT_DATA`, `EVENT_META`, `EVENT_POP`。
- `ERROR_ACK` for overflow/config error/coalesced sticky。

CPU AXI4 Managerはp002のAXI4-to-AXI4-Lite routeを介してCSRへaccessする。Cバス側からfrontend設定CSRへ直接書けるaliasは初期Phaseに含めない。

## Interrupt integration and ABI change

- mailbox/router ABI v1のreserved bit 7を`CBUS_WRITE_EVENT` CPU eventへ割り当てる。
- ABI versionを更新し、JSONからSV/C/Rust定数を同時生成する。既存bit 0〜6、8〜9、16〜23は変更しない。
- `external_cpu_event_set[7]`は`FIFO nonempty || overflow_sticky || config_error_sticky`のlevelを与える。
- source levelが残る間はrouter W1Cと同時にset-winsとなる。firmwareはFIFOをdrainしerrorをclearしてからrouter bit 7をackする。
- CPU coreにはbit 7 pinを追加せず、routerの`cpu_irq_active`を`irq_external_i`へ接続する。

## Clock and CDC

- capture inputはCバスlogic clock、AXI4-Lite CSR/routerはAXI/core clockを想定する。
- event FIFOは既存Gray-pointer async FIFO契約を再利用し、recordをbit同期しない。
- slot設定はAXI clockからCバスclockへshadow commit handshakeで一括転送する。BASE/LIMIT/CONFIGの途中値でmatchしない。
- resetは両domainへcoherentにassertし、deassertは各domainで同期する。reset後slot disabled、FIFO empty、sticky clear。

## Safe defaults

- frontend全体enable=0、全slot disabled。
- event source bit 7 inactive、CPU IRQへ影響なし。
- Cバスwriteをconsume、redirect、waitさせない。
- memory target自体のsafe-default disabledを変更しない。
- 実I/O/memory rangeをRTL defaultに埋め込まない。

## Expected implementation files

- `rtl/ip/cbus_write_event_frontend.sv`
- 必要ならwide async FIFO wrapper。generic FIFOを改変する場合は既存CDC回帰を維持する。
- mailbox/router ABI JSONと生成済みSV/C/Rust定数。
- AXI4-Lite control fabric decodeと`cbus_ip_top` integration。
- WS005 testsのfrontend単体、CDC、router/core-IRQ統合BFM。

## Work packages

- [ ] range slot、event record、FIFO、overflow/priority semanticsを契約化する。
- [ ] ABI bit 7とAXI4-Lite CSR mapをmachine-readable sourceへ追加する。
- [ ] capture frontend、shadow config CDC、event FIFO、CSRを実装する。
- [ ] accepted-write tapをI/O/memory共通request境界へ接続する。
- [ ] router bit 7から`irq_external_i`までをlevel接続する。
- [ ] default-disabled、range/lane/multi-match、FIFO full、CDC/resetをBFM検証する。
- [ ] ABI生成、WS003/WS004/WS005/portable-top回帰を実行する。

## Verification plan

- I/O/memory、range内/外、境界address、4 slot、lane mask、複数match priorityを検査する。
- read、abort-before-accept、invalid、reset中、同一requestのbackpressureでeventを生成しない/重複しない。
- 8 entry FIFOのempty/middle/full、drop、SEQ欠落、head snapshot、POP、overflow clearを検査する。
- FIFO nonempty/error中にrouter W1Cしてもexternal IRQが消えず、drain/clear後にackで解除される。
- slot shadow更新の途中値がCバスclock側へ見えない。
- frontend disabledで既存Cバスresponse、IORDY、AXI write、mailbox/router回帰がbit単位で不変である。

## Completion conditions

- 設定したI/O/memory rangeへのaccepted writeがaddress/data/lane/space付きでCPUから読める。
- event lossはFIFO/SEQ/overflowで観測でき、fullがCバスを永久waitさせない。
- eventは既存routerを通ってuser coreの`irq_external_i`へlevel通知される。
- user core外部ABIへCバス固有pin/event IDを追加しない。
- reset defaultで無効かつ既存RTL/ABI回帰を壊さない。

## Interruption and resume policy

- downstream AXI write成功後だけ通知する必要が出た場合は、snoop frontendを黙ってcommit monitorへ変えずordering/response連携を別Phaseへ戻す。
- 4 slot、depth 8、event record幅が資源制約と両立しない場合は合成probe結果をユーザへ提示する。
- 実Cバスrange、物理IRQ、firmware service policyは本Phaseで推測決定しない。
