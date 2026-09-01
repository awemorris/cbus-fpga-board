# WS004: AXI SoC・RISC-V・DRAMランタイム

最終更新: 2026-09-01

WSID: `ws004`

Status: in-progress (p001 completed; p002 detailed)

Parent: [master plan](../master.md)

Resume point: `ws004p001`でuser core用50-port ABIとsafe stubを完了し、`ws005p005`のcontrol fabric統合後に`ws004p002`を詳細化した。次はp002をQueueへ提案し、単一CPU AXI4 Managerからbehavioral memory、共有AXI4-Lite control plane、Full/Lite各1本のuser target slotへ接続する。Primer DDR wrapperはIP-complete gate後へ延期する。

## Objective

RISC-VファームウェアがAXI4上のDRAM、CSR、DMA、ユーザIPへアクセスし、PC-98の要求を処理できる再現可能なSoC基盤を提供する。

## Scope

- 32-bit AXI4 fabricと32-bit AXI4-Lite CSRバス
- CPUから接続するAXI4 Full 1本、AXI4-Lite 1本のuser target slotとcompile-time safe disable
- ユーザ設計RISC-Vコアを差し替える外部port ABI、stub、ブートROM/RAM、更新方法
- board-independent behavioral memory/BRAM reference targetと、後段のGowin DDRコントローラwrapper/メモリ試験
- CPU、DMA、Cバスターゲットの3 Manager調停
- DRAM、PC-98 host aperture、AXI-Lite bridgeのTarget decode
- ファームウェアBSP、リンカ、起動、例外、タイマ、UART等の最小診断

## Non-goals

- 初期段階の高性能キャッシュ整合性
- Linuxを必須とすること
- ユーザIPへ無制限のCバス/DRAMアクセスを与えること

## Dependencies

- WS002がPrimer 20Kの資源上限と、board wrapper境界を提供する。core外部interface/stubとreference SoC RTLはphysical DDR wrapperに依存させない。
- WS003がCバス由来AXI Managerを提供する。
- WS005/WS006/WS007がCSR、IRQ、DMA、ユーザ領域を提供する。
- CPU、fabric、firmware ABIはboard-independent `cbus_ip_top`へ置き、Primer DDR controllerは同じAXI memory targetを提示するplatform wrapperへ閉じ込める。Mega referenceにも論理interfaceは保つが、Mega用PCB/DDR実機検証をcompletion条件に含めない。

## Phase registry

| Phase | Status | Goal |
| --- | --- | --- |
| [`ws004p001`](phase001-riscv-soc-requirements/phase.md) | completed | ユーザ設計coreのAXI4/IRQ/control/status port ABIとsafe stubを実装する。 |
| [`ws004p002`](phase002-axi-interconnect/phase.md) | planned; ready for Queue proposal | 小規模AXI4/AXI4-Lite interconnect、共有control plane、Full/Lite user target slot、decode、guard、timeoutを実装する。 |
| `ws004p003` | deferred until IP-complete gate | Primer DDR wrapper、初期化、march test、エラー記録を統合する。 |
| `ws004p004` | planned after p001/p002 | CPU、ROM/BRAM reference memory、BSP、診断firmwareをboard-independent環境で起動する。 |
| `ws004p005` | deferred after p003 | Cバス・CPU・DDR・CSRの同時アクセスと実機性能を検証する。 |

## Initial fabric constraints

- Managers: CPU=1 outstanding、Cバス=1、DMA=2〜4を初期上限候補とする。
- Targets: 初期はbehavioral memory/BRAM、保護付きPC-98 memory/I/O aperture、AXI4-Lite bridge。DDRは同じmemory target境界へ後付けする。
- User targets: `0x2000_0000-0x27ff_ffff`にAXI4 Full 1本、`0x2800_0000-0x2800_ffff`にAXI4-Lite 1本を予約する。各slotは既定無効で、無効時は外向きfan-outをgenerate除去可能にし、accessへlocal `DECERR`を返す。
- Cバス由来ManagerからPC-98 apertureへのrouteはdenyする。
- DMA共有領域は非キャッシュ、またはCPUキャッシュ無効から開始する。

## Completion conditions

- クリーン環境からboard-independent reference SoCとRISC-V firmwareを再構築でき、後段でPrimer bitstreamを同じABIから生成できる。
- CPUがDRAM、System CSR、mailbox、DMA CSR、ユーザ領域へ期待通りアクセスできる。
- AXI4 Full 1本とAXI4-Lite 1本のuser target slotを個別に有効/無効化でき、無効時も予約accessが永久waitしない。
- 不正領域、timeout、AXI errorが診断可能で、fabricが停止しない。
- reference memory試験と、物理Phase後のDDR初期化/メモリ試験の結果が起動ごとに観測できる。
- 合成後の資源、Fmax、クロック構成に余裕基準がある。

## Reconsideration boundaries

ユーザcoreが複数AXI Manager、coherency、複数outstanding、追加NMI/debug port等を必要とする場合は、p002実装前にinterface ABIまたはadapter方針をユーザへ戻す。DDR IPのlicense、資源/Fmax、配布条件が目標と両立しない場合はplatform選択を再検討する。
