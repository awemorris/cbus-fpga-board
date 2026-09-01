# WS003: Cバス・ターゲット/AXIブリッジ

最終更新: 2026-09-01

WSID: `ws003`

Status: in-progress

Parent: [master plan](../master.md)

Resume point: `ws003p006`まで完了し、CバスI/Oから共通System CSRまで自己検査済みである。`ws001p003`のmemory cycle根拠を入力に詳細化した`ws003p004`を、board-independent 24-bit memory target RTLの次Queueへ提案できる。実機I/O baseは未選定であり、`ws003p005`物理試作はIP-complete gate後へ延期する。

## Objective

PC-98がCバスI/O/メモリ空間からFPGA内AXI4/AXI4-Lite資源へ、正しいバイトレーン、wait、エラー、CDCでアクセスできる受動ターゲット経路を完成する。

## Scope

- CバスBFMとトランザクションモニタ
- `cbus_target_engine`によるI/O/メモリサイクル検出と応答
- 正規化要求 `cbus_req {space, write, addr, data16, be2, tag}` と応答
- 非同期要求/応答FIFOによるCDC
- `cbus_to_axi_bridge`、AXI4-Lite変換、デコード、timeout/error
- PC-98 I/Oポートから読める最小System CSR

## Non-goals

- Cバスのバス所有権を取得してアドレスを駆動すること
- CPU、DRAM、DMA、完成ユーザIPの統合
- 根拠未確定のメモリサイクルを早期MVPへ含めること

## Dependencies

- WS001の信号・タイミング・バイトレーン契約。
- WS002の論理pad契約と安全リセット。BFMによる論理シミュレーションは物理試作より先行可能。
- `cbus_target_engine`以下はboard-independentな`cbus_ip_top`へ入り、board top、package pin、DDR/PLL primitiveへ依存しない。Primerがprimary、Megaはreference回帰とする。
- WS005/WS004/WS007は安定したAXI4-Lite従属ポートを利用する。

## Phase registry

| Phase | Status | Goal |
| --- | --- | --- |
| [`ws003p001`](phase001-bfm-target-mvp/phase.md) | completed | BFM、target engine、固定ID CSRで8/16-bit I/Oサイクルを検証する。 |
| [`ws003p002`](phase002-cdc-axil-bridge/phase.md) | completed | CDC request/response FIFOとC-bus-to-AXI4-Liteブリッジを統合する。 |
| [`ws003p003`](phase003-axil-guard-timeout/phase.md) | completed | AXI4-Lite protected route、region guard、timeout/quarantine、エラー記録を追加する。 |
| [`ws003p004`](phase004-memory-target-rtl/phase.md) | planned; Queue提案可能 | default-disabledの24-bit Cバスメモリtargetと連続アクセスをboard-independent RTLで実装する。 |
| `ws003p005` | deferred until IP-complete gate | ユニバーサル基板上でID/CSRアクセスを実証する。 |
| [`ws003p006`](phase006-system-csr/phase.md) | completed | AXI4-Lite System CSRを実装し共通IPへ統合する。 |

## Proposed module boundaries

- `cbus_subsystem/cbus_target_engine`
- `cbus_target_axil_subsystem/cbus_req_rsp_cdc/async_fifo`
- `cbus_to_axil_bridge`
- `axi4_to_axil_bridge`
- `axil_guard_timeout` と `cbus_target_guarded_axil_subsystem`
- `system_csr`
- board-independent `cbus_ip_top`。Primer primary topとMega reference topから同一port contractでinstantiateする。

## Completion conditions

- 8/16-bit I/O読書き、奇偶バイトレーン、wait挿入、リセット中断、無効アクセスが自己検査BFMで通る。
- AXI側のbackpressureまたは無応答でCバスが永久停止せず、タイムアウト原因を読める。
- Cバス由来AXI ManagerはPC-98 host apertureへアクセスできない。
- 実機からID、版、状態、scratch CSRを反復して読書きできる。

## Reconsideration boundaries

Cバスwaitの上限、サンプリングクロック、バイトレーンが資料と実測で一致しない場合は、対応機種を限定するかタイミング設計をWS001へ戻す。
