# ws003p001: CバスBFMと最小ターゲットMVP

最終更新: 2026-08-31

WSID: `ws003`

Phase ID: `p001`

Combined ID: `ws003p001`

Status: planned after WS001 basic-cycle evidence

Parent: [WS003](../ws.md)

## Objective

実機へ出力を接続する前に、根拠のあるCバスI/Oサイクルを生成・監視する自己検査BFMと、固定ID/scratchレジスタへ応答する最小ターゲットをシミュレーションで成立させる。

## Dependencies and fixed decisions

- WS001にI/O read/write、8/16-bit、wait、リセットのタイミング契約がある。
- 物理LVCはモデル境界外だが、論理DIR/OEとHigh-Z条件は検査する。
- このPhaseではAXI interconnectを実装せず、最小レジスタ従属モデルへ接続する。

## Scope

- CバスI/O read/writeを駆動するBFM
- contention、X、応答時間、byte enableを検査するmonitor/assertion
- `cbus_target_engine`の限定実装
- 固定ID、version、scratch、statusレジスタ
- timeout、不正選択、reset abortのテスト

## Non-goals

- AXI4 Full、DDR、CPU、割り込み、DMA
- メモリサイクル、外部バスマスタ、全機種タイミング
- 実機接続またはCバス信号の無根拠な駆動

## Work packages

- [ ] 信号型と正規化 `cbus_req/cbus_rsp` 契約を定義する。
- [ ] I/O read/write BFMとモニタを実装する。
- [ ] 最小target engineとレジスタモデルを実装する。
- [ ] 8/16-bit、奇偶、wait、無効、reset、timeoutケースを追加する。
- [ ] lint、シミュレーション、波形確認を実行し再現コマンドを記録する。

## Completion conditions

- 根拠を持つ全基本I/Oケースが自己検査テストでpassする。
- 読取り以外または非選択時にデータ出力OEが立たない。
- reset/config-not-readyモデル中は全Cバス出力が無効である。
- byte enableと16-bitデータの変換が期待値と一致する。
- timeoutと不正サイクルが永久待ちせず、明示的な状態になる。
- 使用HDL、シミュレータ、コマンド、seed、テスト一覧が記録される。

## Expected evidence

lintログ、全テスト名と結果、失敗時に有用な波形、assertion一覧、変更ファイル、仕様台帳への参照を記録する。

## Interruption and resume record

Not started. タイミング契約が未確定または複数解釈になる場合は、BFMへ推測を固定せず `uncleared` とし、必要な資料または実測をWS001へ戻す。
