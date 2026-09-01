# WS001: Cバス仕様・インターフェース契約

最終更新: 2026-09-01

WSID: `ws001`

Status: in-progress

Parent: [master plan](../master.md)

Resume point: board-independent IPを先に完成させる方針により、次は詳細化済み`ws001p004`の従来DMA/外部バスマスタ契約を調査Queueへ提案できる。実機と測定器を要する`ws001p005`互換性マトリクスはIP-complete gate後へ延期する。

## Objective

Cバスの信号、電気条件、転送タイミング、I/O・メモリ・DMA・バス所有権を、RTLと回路設計が参照できる検証可能な契約へ変換する。

初期の設計・互換性試験・保証対象は386以降とする。古い世代は資料profileを保持するが、初期実装での対応条件にはしない。

## Scope

- 98ピン/100ピンという呼称を含むコネクタと信号の正式な対応
- 必須、任意、予約、電源、GND信号の分類
- 入力、出力、双方向、オープンコレクタ相当、High-Z条件
- I/O、メモリ、割り込み、従来DMA、外部バスマスタのサイクル
- `AB0/BHE`等による8/16-bitバイトレーン意味論
- 対象機・クロック・ウェイト・電気条件の差異と証拠の信頼度
- 論理RTLポート、基板ネット、コネクタピンの追跡可能な命名規則

## Non-goals

- 根拠のないWeb記事や既存回路図一件だけを正式仕様とみなすこと
- このWorkstream内でFPGA、LVC、PCBを確定または実装すること
- 未確認機種への互換性を推測すること

## Dependencies

- PC-9800/Cバスの一次資料、対象実機、既存ボードまたは信頼できる測定結果が必要。
- WS002は本Workstreamの電圧・方向・ピン数を入力にする。
- WS003とWS006は本Workstreamのタイミング契約を入力にする。

## Phase registry

| Phase | Status | Goal |
| --- | --- | --- |
| [`ws001p001`](phase001-evidence-baseline/phase.md) | completed | 出典と不確実性を含むCバス証拠台帳を作る。 |
| [`ws001p002`](phase002-signal-matrix/phase.md) | completed | コネクタから論理RTLまでの信号・方向・電気マトリクスを確定する。 |
| [`ws001p003`](phase003-timing-contract/phase.md) | completed | I/O/メモリ/割り込みのサイクル表とタイミング契約を作る。 |
| [`ws001p004`](phase004-dma-busmaster-contract/phase.md) | planned; Queue提案可能 | 従来DMAと外部バスマスタの調停・転送契約を作る。 |
| `ws001p005` | deferred until IP-complete gate | 対象PC-9800機種の互換性マトリクスと実測差分を管理する。 |

## Completion conditions

- 使用する全Cバスネットについて、ピン番号、名称、方向、電気条件、ドライブ条件、リセット状態、根拠が追跡できる。
- サポートする各サイクルに開始、サンプル、応答、終了、タイムアウト条件がある。
- 不明点は不明のまま明示され、依存するPhaseが誤ってreadyになっていない。
- RTLポート、制約ファイル、回路図、テストBFMが同じ機械可読信号台帳から照合できる。

## Reconsideration boundaries

資料間で電圧、方向、DMA調停、クロック意味論が矛盾する場合は、一方を推測で採用せず実測計画または対象機限定をユーザへ提示する。
