# WS003: Cバス・ターゲット/AXIブリッジ

最終更新: 2026-08-31

WSID: `ws003`

Status: planned

Parent: [master plan](../master.md)

Resume point: WS001の基本サイクル契約後、`ws003p001`のBFMと最小ターゲット仕様をQueueへ提案する。

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
- `cbus_target_engine`以下はPrimer/Mega共通の`cbus_ip_top`へ入り、board top、package pin、DDR/PLL primitiveへ依存しない。
- WS005/WS004/WS007は安定したAXI4-Lite従属ポートを利用する。

## Phase registry

| Phase | Status | Goal |
| --- | --- | --- |
| [`ws003p001`](phase001-bfm-target-mvp/phase.md) | planned after WS001 basic-cycle evidence | BFM、target engine、固定ID CSRで8/16-bit I/Oサイクルを検証する。 |
| `ws003p002` | planned | CDC request/response FIFOとC-bus-to-AXI4-Liteブリッジを統合する。 |
| `ws003p003` | planned | AXI4 interconnect、region guard、timeout、エラー記録を追加する。 |
| `ws003p004` | proposed | 根拠が揃ったCバスメモリサイクルと連続アクセスを追加する。 |
| `ws003p005` | proposed | ユニバーサル基板上でID/CSRアクセスを実証する。 |

## Proposed module boundaries

- `cbus_subsystem/cbus_target_engine`
- `cbus_subsystem/cbus_req_async_fifo` と `cbus_rsp_async_fifo`
- `cbus_to_axi_bridge`
- `axi4_to_axil_bridge`
- `axi_region_guard` と `axi_timeout`
- `system_csr`
- board-independent `cbus_ip_top`。Primer/Mega固有topから同一port contractでinstantiateする。

## Completion conditions

- 8/16-bit I/O読書き、奇偶バイトレーン、wait挿入、リセット中断、無効アクセスが自己検査BFMで通る。
- AXI側のbackpressureまたは無応答でCバスが永久停止せず、タイムアウト原因を読める。
- Cバス由来AXI ManagerはPC-98 host apertureへアクセスできない。
- 実機からID、版、状態、scratch CSRを反復して読書きできる。

## Reconsideration boundaries

Cバスwaitの上限、サンプリングクロック、バイトレーンが資料と実測で一致しない場合は、対応機種を限定するかタイミング設計をWS001へ戻す。
