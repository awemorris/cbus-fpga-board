# ws003p004: 24-bit Cバスメモリtarget RTL

最終更新: 2026-09-01

WSID: `ws003`

Phase ID: `p004`

Combined ID: `ws003p004`

Status: completed

Parent: [WS003](../ws.md)

## Objective

386以降型のCバスメモリread/writeを、物理基板や実アドレス割当へ依存しないdefault-disabled IPとして実装し、24-bit address、8/16-bit lane、wait、連続cycle、CDC/AXI errorを自己検査BFMで確定する。

## Dependencies and source contracts

- [`ws001p003`](../../ws001-cbus-contract/phase003-timing-contract/phase.md)と[`cycle-contract.csv`](../../ws001-cbus-contract/cycle-contract.csv): memory read/write、IORDY、laneのfamily contract。
- [`timing-contract.md`](../../ws001-cbus-contract/timing-contract.md): 386/486/Pentium profileと非同期capture方針。
- [`ws003p002`](../phase002-cdc-axil-bridge/phase.md): request/response CDC、tagによる遅延response隔離、AXI4-Lite変換。
- [`ws003p003`](../phase003-axil-guard-timeout/phase.md): region guard、timeout、quarantine、fault record。
- [`ws002p002`](../../ws002-fpga-platform/phase002-portable-top-safety/phase.md): board-independent topと物理wrapperの安全gate。

## Scope

- I/O engineと独立した`cbus_memory_target_engine`。
- `SALE`で上位addressを保持し、cycle開始時の下位addressと結合する24-bit capture。
- `MRC` read、`MWC`かつ`MWE`でqualifiedされたwrite、`AB0/BHE`によるbyte enable。
- default-disabledかつparameterizedなCバスmemory apertureとAXI target base。
- 既存request/response CDC、tag、AXI4-Lite bridge/guardを再利用するmemory route。
- back-to-back/連続cycle、wait、timeout、abort、reset、stale responseのBFM。
- `cbus_ip_top`へboard-independentな`cbus_sale_i`を追加する論理interface拡張。

## Excluded

- 実機用Cバスメモリbase/size、ROM/RAM競合回避、PnP/driverでの予約方法の決定。
- Primer SO-DIMM pin、A39 LVC、generation selector、carrier配線、CSTの確定。
- 8086/70116/80286固有memory profile。
- AXI4 Full burst、DRAM controller、RISC-V core、DMA、bus master。
- 回路図、PCB、Gowin合成、実機試験。

## Interface correction and safe default

`SALE`はWS001 signal matrixのA39世代多重信号として存在するが、現行69 endpointと`cbus_ip_top` portには未収容である。本Phaseでは事実を次の境界で扱う。

- 共通IPにactive-high論理入力`cbus_sale_i`を追加する。
- BFMは386以降profileとしてSALE pulseを与える。
- 既存Primer/Mega wrapperではphysical mappingが承認されるまで`cbus_sale_i=0`へ固定し、memory aperture既定無効を維持する。
- WS001 endpoint数、Primer pin/LVC/CST更新はphysical IP-complete gate後のWS002 planningへ戻す。本Phaseで空きpinを推測割当しない。
- `CBUS_MEM_ENABLE=0`のときMRC/MWC/MWE/SALEは新規応答、DB OE、IORDY OEを発生させない。

追加parameterの初期契約:

| Parameter | Safe default | Meaning |
| --- | ---: | --- |
| `CBUS_MEM_ENABLE` | `1'b0` | 0でmemory target decodeと応答を完全に無効化する。 |
| `CBUS_MEM_BASE` | `24'h000000` | enable時のCバス側base。未割当placeholder。 |
| `CBUS_MEM_ADDR_MASK` | `24'hffffff` | aperture mask。実sizeは後段で決める。 |
| `AXIL_MEM_TARGET_BASE` | Phase内test address | Cバスmemory apertureを写像するboard非依存AXI base。 |

testbenchだけが非衝突のtest base/maskをenableする。実機割当済みという意味を持たせない。

## Memory cycle contract

- SALEの有効pulseで`AB[23:17]`を保持する。latchが有効でないreset直後はmemory cycleへ応答しない。
- cycle開始時に`AB[16:0]`と保持済み`AB[23:17]`を一つの24-bit request addressへ固定し、cycle途中のbus変化で書き換えない。
- readは`MRC=Low`だけを開始条件とし、response確定後だけDB OEを要求する。
- writeは`MWC=Low`だけではcommitせず、同じcycleで`MWE=Low`が確認された場合だけ一件のwrite requestを発行する。
- `AB0/BHE`から`BE[1:0]`を作り、`00`はinvalid/non-responseにする。
- I/Oとmemory strobeが同時にactive、MRCとqualified writeが同時、別cycleのstrobeが解放前に始まる場合はinvalidとして駆動しない。
- 各requestは`space=memory`と24-bit addressを保持する。既存16-bit I/O request構造を曖昧に拡張せず、共通request width/spaceを明示的に改定する。

## Proposed architecture

```text
cbus_sale_i + AB[23:0] --> address capture
MRC/MWC/MWE/BHE -------> cbus_memory_target_engine
                                  |
                      cbus_req {space=mem, addr24, ...}
                                  |
                 shared req/rsp CDC + tag isolation
                                  |
                     C-bus-to-AXI memory mapping
                                  |
                    guard / test AXI subordinate
```

I/O engineとmemory engineの同時requestは明示的arbiterで拒否または一意に選択し、wire-ORしない。一般SoC multi-manager fabricは本Phaseへ含めない。

## Expected implementation files

New files候補:

- `rtl/cbus/cbus_memory_target_engine.sv`
- `plan/ws003-target-bridge/tests/tb_cbus_memory_target.sv`
- `plan/ws003-target-bridge/tests/tb_cbus_memory_axil.sv`

Update候補:

- `rtl/cbus/cbus_target_axil_subsystem.sv`またはmemory専用wrapper
- `rtl/axi/cbus_to_axil_bridge.sv`
- `rtl/ip/cbus_ip_top.sv`
- `rtl/platform/cbus_board_shell.sv`
- Primer/Mega reference top（`cbus_sale_i=0`の安全tieのみ）
- WS003/WS002のIcarus回帰scriptとportable-top validator

実装時にI/O path回帰を大きく書き換える必要があれば、共有request contractの小Phaseへ分離する。

## Work packages

- [x] 24-bit/spaceを持つ共通request contractを明文化し、既存I/O変換との後方互換を定める。
- [x] SALE address captureとmemory target engineを実装する。
- [x] default-disabled memory aperture decodeとparameter assertionを追加する。
- [x] MRC read、MWC+MWE write、lane、wait/timeout/abortをCDC/AXI routeへ統合する。
- [x] I/O-memory同時/overlapのinvalid処理とsticky観測を追加する。
- [x] wrapperへlogical SALEを安全tieで透過し、物理mappingを追加しない。
- [x] 単体、統合、既存回帰をIcarusで自己検査する。
- [x] SALE physical endpoint不足をWS001/WS002のphysical backlogへ同期する。

## Verification plan

- SALE前後で上位addressを変化させ、保持値だけがdecode/requestに使われる。
- 24-bit base/maskの内外、上端/下端、連続した別上位addressを検査する。
- MRC read、MWC only、MWE only、MWC+MWE write、同時不正strobeを検査する。
- lower/upper byte、word、`BE=00`、odd addressを検査する。
- read data OEは選択read response後だけ、writeでは常にoffである。
- wait、AXI backpressure/error、Cバスtimeout、platform abort、reset、late response/tag隔離から復帰する。
- back-to-back I/O/memory、memory/memory cycleでrequest重複や前cycle data残留がない。
- `CBUS_MEM_ENABLE=0`とboard wrapper safe tieで、既存I/O CSRおよび全physical OE回帰が不変である。
- Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でwarningなし。

## Completion conditions

- 386以降family contractの24-bit memory read/writeがboard-independent BFMで再現できる。
- 上位address latch、MWC+MWE qualification、8/16-bit lane、連続cycleが決定的である。
- timeout/reset/abort/invalid後にDB/IORDY OEが安全に解除され、遅延responseが次cycleへ混入しない。
- memory apertureはsafe defaultで無効で、実アドレスとphysical SALE pinを未決定のまま完了できる。
- WS002/WS003の既存I/O/portable-top回帰がすべてPASSする。

## Interruption and resume policy

- SALEの資料上のpolarity/timingが既存契約と矛盾する場合は推測せずWS001へ戻す。
- 物理SALE pinがないことを理由にsimulationを省略せず、logical portとsafe tieまでで完了判定する。
- 実memory base、DDR、multi-manager fabric、Gowin primitiveが必要になった場合は本Phaseを拡大せずWS004/WS002へ戻す。

## Execution result

2026-09-01に`Q20260901-015`で完了した。

- `cbus_memory_target_engine`を追加し、active-high logical `SALE`で`AB[23:17]`を保持してcycle開始時の`AB[16:0]`と結合する24-bit read/write targetを実装した。
- memory apertureは`CBUS_MEM_ENABLE=0`を既定とし、Cバスbase/maskと32-bit aligned AXI test target baseにalignment assertionを設けた。実アドレス割当は行っていない。
- 共通CDC packetを`{tag, space_memory, write, addr24, wdata16, be2}`へ拡張し、既存I/O requestは上位zeroで後方互換を維持した。
- memory addressは自然byte mappingとし、Cバスaddress bit 1でAXI lower/upper halfwordと`WSTRB[1:0]/[3:2]`を選択する。既存I/O registerのword-expanded mappingは変更していない。
- I/O/memory engineを明示arbiterで共有CDC/tag/AXI guard routeへ接続し、同時strobe、MRC+write、MWE-only、`BE=00`を非駆動で拒否してsticky invalidへ反映した。
- `cbus_ip_top`へlogical `cbus_sale_i`とmemory parameterを追加した。Primer/Megaの69 endpoint、CST、物理OEは変更せず、共通board shell内で`cbus_sale_i=0`へ固定した。
- 新規BFMはmemory engine 618、CDC/AXI統合182、共通IP統合806の計1606 checksをPASSした。既存WS003 656 checksも不変で、WS003合計は2262 checksとなった。
- WS002 3377、WS004 30、WS005 327を合わせたHDL合計5996 checks、ABI contract checks、WS001/WS002 validatorをPASSした。Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でwarningはない。
- 実memory base/size、物理`SALE` endpoint/LVC/CST、ROM/RAM競合回避、PnP/driver、DRAM/AXI4 Full、Gowin合成、回路図、PCB、実機は計画境界へ残した。
