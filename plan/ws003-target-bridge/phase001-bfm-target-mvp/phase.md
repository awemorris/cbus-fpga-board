# ws003p001: CバスBFMと最小ターゲットMVP

最終更新: 2026-09-01

WSID: `ws003`

Phase ID: `p001`

Combined ID: `ws003p001`

Status: completed

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

- [x] 信号型と正規化 `cbus_req/cbus_rsp` 契約を定義する。
- [x] I/O read/write BFMとモニタを実装する。
- [x] 最小target engineとレジスタモデルを実装する。
- [x] 8/16-bit、奇偶、wait、無効、reset、timeoutケースを追加する。
- [x] lint、シミュレーション、波形確認を実行し再現コマンドを記録する。

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

2026-09-01 Queue `Q20260901-006`で完了。未確認の実機/LVC遅延を固定せず、WS001の386以降profileからシミュレーション条件だけを使用した。

## Execution result

- board非依存の[`cbus_req/cbus_rsp`契約](../cbus-req-rsp-contract.md)を定義した。MVPは一件outstanding、in-order responseで、AXI/CDCは含めない。
- `rtl/cbus/cbus_target_engine.sv`にI/O strobe 2段同期、mid-cycle arm防止、8/16-bit byte-enable、read OE、IORDY wait、bounded timeout、reset/platform abort、sticky faultを実装した。
- `rtl/cbus/cbus_target_regs.sv`にID=`0xcb98`、version=`0x0001`、byte-write対応scratch、status CSRを実装した。base `0x00d0`はシミュレーション仮値である。
- tri-state DBを持つBFMとcontinuous monitorを追加した。host/target contention、driven X、write中のtarget drive、reset/not-ready出力を失敗にする。
- 386以降profileのno-wait read 239 ns以内、IORDY assertion 80 ns以内、Low幅40 ns～7 us、read hold 5 ns以上を自己検査した。
- `platform_ready`をcycle途中で有効化してもarmせず、drop時にはOEとrequestを即時gateすることを確認した。

再現コマンド:

```sh
plan/ws003-target-bridge/tests/run_iverilog.sh
```

環境と結果:

```text
Icarus Verilog version 12.0 (stable)
Icarus Verilog runtime version 12.0 (stable)
SEED=1 (deterministic BFM)
PASS: 157 checks
```

compileは`-g2012 -Wall -Wimplicit`でwarningなし。VCDは`plan/ws003-target-bridge/temp/iverilog/tb_cbus_target_mvp.vcd`へ生成し、Git管理外とした。既存WS001/WS002 validatorも全てPASSした。

AXI、CDC FIFO、memory cycle、IRQ、DMA、board top、constraint、LVC、実機I/O address選定は実装していない。
