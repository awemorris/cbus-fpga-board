# CバスFPGAボード Queue Book

最終更新: 2026-09-01

Queue ID: `Q20260901-015`

Queue status: finished

Parent: [master plan](master.md)

## 1. Queue proposal

`ws003p004`だけを実行し、386以降family contractに従うdefault-disabledの24-bit Cバスメモリtargetをboard-independent RTLへ追加する。`SALE`上位address保持、`MRC` read、`MWC+MWE` write、8/16-bit lane、連続cycle、既存CDC/tag/AXI guard route、I/O-memory競合拒否を実装・検証する。

ユーザは2026-09-01に「`ws003p004`を実行します」と指示した。今回のtimeboxは、このセッションで合理的に完了または`uncleared`判定までとする。

## 2. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws003p004` | [phase.md](ws003-target-bridge/phase004-memory-target-rtl/phase.md) | completed | 2026-09-01 user explicitly approved execution |

## 3. Included

- 24-bit addressとI/O/memory spaceを明示する共通request contract。
- 独立した`cbus_memory_target_engine`、active-high logical `SALE` capture、memory aperture decode。
- `MRC` read、`MWC+MWE` qualified write、byte lane、wait、timeout、abort、reset。
- I/O/memory request arbiter、同時strobe拒否、既存CDC/tag/AXI-Lite bridge/guard routeの再利用。
- `CBUS_MEM_ENABLE=0`のsafe defaultとparameter assertion。
- `cbus_ip_top`へのlogical `cbus_sale_i`追加、board wrapperでの0固定、物理pin/CST非変更。
- memory engine単体、CDC/AXI統合、既存I/O/portable-topの自己検査回帰。
- 実行結果のM/W/P/Q同期と完了境界でのcommit/push。

## 4. Excluded

- 実機用Cバスメモリbase/size、ROM/RAM競合回避、PnP/driver予約。
- 物理`SALE` pin、LVC、carrier配線、CST、generation selector。
- 8086/70116/80286固有profile、AXI4 Full、DRAM、CPU、DMA、bus master。
- Gowin合成、回路図、PCB、実機試験。

## 5. Dependencies and uncertainty

- `ws001p003`のmemory-cycle/IORDY/lane契約と`ws003p002/p003`のCDC/tag/guard契約を維持する。
- memory AXI target baseはPhase内のboard-independent test placeholderであり、実機割当を意味しない。
- 物理`SALE` endpoint不足はWS001/WS002 backlogへ記録し、本Queueでpinを推測しない。
- 共通request変更が既存I/O応答互換を壊す場合は、I/O pathを優先して復旧し、解消不能な設計判断だけを`uncleared`へ戻す。

## 6. Completion decision

[ws003p004 Phase Book](ws003-target-bridge/phase004-memory-target-rtl/phase.md)のcompletion conditionsを満たし、WS002/WS003の既存回帰を含む指定検証がwarningなしでPASSした場合に`completed`とする。合理的に完了できない場合は理由、保存した成果、再開条件を記録して`uncleared`とする。

## 7. Authorization boundary

2026-09-01にユーザが「`ws003p004`を実行します」と指示し、本Queueの実行を承認した。

## 8. Execution result

`ws003p004` completed。

- active-high logical `SALE`で上位7 bitを保持する独立`cbus_memory_target_engine`を追加し、24-bit aperture decode、`MRC` read、`MWC+MWE` qualified write、byte lane、wait/timeout/abort/resetを実装した。
- 共通request/CDC packetをI/O/memory space付き24-bit addressへ拡張し、既存I/Oは上位zeroと従来word-expanded AXI mappingを維持した。
- memoryは自然byte mappingを使い、address bit 1で32-bit AXI lower/upper halfwordと対応`WSTRB`を選択する。Cバスbase/maskとAXI target baseにはalignment assertionを追加した。
- I/O/memory engineを明示arbiterで共有CDC/tag/AXI guardへ統合し、同時/overlap strobeを非駆動で拒否してsticky invalidへ記録した。
- memoryは`CBUS_MEM_ENABLE=0`が既定である。`cbus_ip_top`へlogical `cbus_sale_i`を追加したが、Primer/Mega共通board shellは0へ固定し、69 endpoint、CST、物理OEを変更していない。
- 新規memory engine 618、CDC/AXI統合182、共通IP統合806の1606 checksを追加した。既存656を含むWS003は2262 checks、WS002 3377、WS004 30、WS005 327を合わせたHDL合計5996 checksをPASSした。
- mailbox ABI v1の31 registers、17 events、16 aliases、SV/C各12 checks、WS001 signal/platform/timing、WS002 pin/constraint/portable-top、WS004 core-interface validatorがすべてPASSした。
- 実memory base/size、ROM/RAM競合回避、PnP/driver、物理A39 `SALE`/LVC/selector/CST、DRAM/AXI4 Full、Gowin合成、回路図、PCB、実機は後続計画へ残した。
