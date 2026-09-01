# WS004: AXI SoC・RISC-V・DRAMランタイム

最終更新: 2026-09-01

WSID: `ws004`

Status: planning

Parent: [master plan](../master.md)

Resume point: RISC-V優先順位の再整理後、共通`cbus_ip_top`内のCPU/boot候補と、primary targetのPrimer 20K DDR wrapperへ接続する共通AXI memory境界を比較する。Mega 138KはIP interfaceのreferenceであり、実機SoC受入の対象にしない。

## Objective

RISC-VファームウェアがAXI4上のDRAM、CSR、DMA、ユーザIPへアクセスし、PC-98の要求を処理できる再現可能なSoC基盤を提供する。

## Scope

- 32-bit AXI4 fabricと32-bit AXI4-Lite CSRバス
- RISC-Vソフトコア、ブートROM/RAM、デバッグ/更新方法
- Gowin DDRコントローラwrapperとメモリ試験
- CPU、DMA、Cバスターゲットの3 Manager調停
- DRAM、PC-98 host aperture、AXI-Lite bridgeのTarget decode
- ファームウェアBSP、リンカ、起動、例外、タイマ、UART等の最小診断

## Non-goals

- 初期段階の高性能キャッシュ整合性
- Linuxを必須とすること
- ユーザIPへ無制限のCバス/DRAMアクセスを与えること

## Dependencies

- WS002がTang、クロック、DDR wrapper、資源制約を提供する。
- WS003がCバス由来AXI Managerを提供する。
- WS005/WS006/WS007がCSR、IRQ、DMA、ユーザ領域を提供する。
- CPU、fabric、firmware ABIはboard-independent `cbus_ip_top`へ置き、Primer DDR controllerは同じAXI memory targetを提示するplatform wrapperへ閉じ込める。Mega referenceにも論理interfaceは保つが、Mega用PCB/DDR実機検証をcompletion条件に含めない。

## Phase registry

| Phase | Status | Goal |
| --- | --- | --- |
| `ws004p001` | planned | RISC-Vコア、ツールチェーン、boot方式、クロック、資源予算を選定する。 |
| `ws004p002` | planned | 小規模AXI4/AXI4-Lite interconnect、decode、guard、timeoutを実装する。 |
| `ws004p003` | planned | DDR wrapper、初期化、march test、エラー記録を統合する。 |
| `ws004p004` | planned | CPU、ROM/RAM、BSP、診断ファームウェアを起動する。 |
| `ws004p005` | proposed | Cバス・CPU・DRAM・CSRの同時アクセスと性能を検証する。 |

## Initial fabric constraints

- Managers: CPU=1 outstanding、Cバス=1、DMA=2〜4を初期上限候補とする。
- Targets: DRAM、保護付きPC-98 memory/I/O aperture、AXI4-Lite bridge。
- Cバス由来ManagerからPC-98 apertureへのrouteはdenyする。
- DMA共有領域は非キャッシュ、またはCPUキャッシュ無効から開始する。

## Completion conditions

- クリーン環境からFPGA bitstreamとRISC-V firmwareを再構築できる。
- CPUがDRAM、System CSR、mailbox、DMA CSR、ユーザ領域へ期待通りアクセスできる。
- 不正領域、timeout、AXI errorが診断可能で、fabricが停止しない。
- DDR初期化とメモリ試験の結果が起動ごとに観測できる。
- 合成後の資源、Fmax、クロック構成に余裕基準がある。

## Reconsideration boundaries

CPU/DDR IPのライセンス、ツール再現性、資源/Fmax、配布条件が目標と両立しない場合は、コアまたはTang品種の選択をユーザへ戻す。
