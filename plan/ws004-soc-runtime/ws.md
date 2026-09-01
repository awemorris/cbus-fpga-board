# WS004: AXI SoC・RISC-V・DRAMランタイム

最終更新: 2026-09-01

WSID: `ws004`

Status: planned

Parent: [master plan](../master.md)

Resume point: 詳細化済み`ws004p001`でRISC-V SoC IP要件、コア候補、boot/reset、AXI/IRQ/memory境界を調査する。DDRなしのbehavioral memory/BRAM reference SoCを先に成立させ、Primer DDR wrapperを扱う`ws004p003`はIP-complete gate後へ延期する。

## Objective

RISC-VファームウェアがAXI4上のDRAM、CSR、DMA、ユーザIPへアクセスし、PC-98の要求を処理できる再現可能なSoC基盤を提供する。

## Scope

- 32-bit AXI4 fabricと32-bit AXI4-Lite CSRバス
- RISC-Vソフトコア、ブートROM/RAM、デバッグ/更新方法
- board-independent behavioral memory/BRAM reference targetと、後段のGowin DDRコントローラwrapper/メモリ試験
- CPU、DMA、Cバスターゲットの3 Manager調停
- DRAM、PC-98 host aperture、AXI-Lite bridgeのTarget decode
- ファームウェアBSP、リンカ、起動、例外、タイマ、UART等の最小診断

## Non-goals

- 初期段階の高性能キャッシュ整合性
- Linuxを必須とすること
- ユーザIPへ無制限のCバス/DRAMアクセスを与えること

## Dependencies

- WS002がPrimer 20Kの資源上限と、board wrapper境界を提供する。RISC-V要件とreference SoC RTLはphysical DDR wrapperに依存させない。
- WS003がCバス由来AXI Managerを提供する。
- WS005/WS006/WS007がCSR、IRQ、DMA、ユーザ領域を提供する。
- CPU、fabric、firmware ABIはboard-independent `cbus_ip_top`へ置き、Primer DDR controllerは同じAXI memory targetを提示するplatform wrapperへ閉じ込める。Mega referenceにも論理interfaceは保つが、Mega用PCB/DDR実機検証をcompletion条件に含めない。

## Phase registry

| Phase | Status | Goal |
| --- | --- | --- |
| [`ws004p001`](phase001-riscv-soc-requirements/phase.md) | planned; research Queue提案可能 | RISC-V SoC IP要件、コア選定基準、boot/reset、bus/IRQ/memory境界を確定する。 |
| `ws004p002` | planned after p001/ws005p005 | 小規模AXI4/AXI4-Lite interconnect、decode、guard、timeoutを実装する。 |
| `ws004p003` | deferred until IP-complete gate | Primer DDR wrapper、初期化、march test、エラー記録を統合する。 |
| `ws004p004` | planned after p001/p002 | CPU、ROM/BRAM reference memory、BSP、診断firmwareをboard-independent環境で起動する。 |
| `ws004p005` | deferred after p003 | Cバス・CPU・DDR・CSRの同時アクセスと実機性能を検証する。 |

## Initial fabric constraints

- Managers: CPU=1 outstanding、Cバス=1、DMA=2〜4を初期上限候補とする。
- Targets: 初期はbehavioral memory/BRAM、保護付きPC-98 memory/I/O aperture、AXI4-Lite bridge。DDRは同じmemory target境界へ後付けする。
- Cバス由来ManagerからPC-98 apertureへのrouteはdenyする。
- DMA共有領域は非キャッシュ、またはCPUキャッシュ無効から開始する。

## Completion conditions

- クリーン環境からboard-independent reference SoCとRISC-V firmwareを再構築でき、後段でPrimer bitstreamを同じABIから生成できる。
- CPUがDRAM、System CSR、mailbox、DMA CSR、ユーザ領域へ期待通りアクセスできる。
- 不正領域、timeout、AXI errorが診断可能で、fabricが停止しない。
- reference memory試験と、物理Phase後のDDR初期化/メモリ試験の結果が起動ごとに観測できる。
- 合成後の資源、Fmax、クロック構成に余裕基準がある。

## Reconsideration boundaries

CPU/DDR IPのライセンス、ツール再現性、資源/Fmax、配布条件が目標と両立しない場合は、コアまたはTang品種の選択をユーザへ戻す。
