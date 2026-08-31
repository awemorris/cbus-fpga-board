# CバスFPGAボード Queue Book

最終更新: 2026-09-01

Queue ID: `Q20260901-006`

Queue status: finished

Parent: [master plan](master.md)

## 1. 現在の実行許可

2026-09-01にユーザが、直前のhandoffで次候補として提示した`ws003p001`のQueue実行を明示的に指示した。

`ws003p001`として、386以降target profileのCバスI/O read/writeを生成する自己検査BFM、board非依存の最小`cbus_target_engine`、固定ID/version/scratch/status CSRをiverilogで実装・検証する。AXI、メモリcycle、IRQ、DMA、bus-master、board top、constraint、回路図、PCB、実機試験は含めない。

## 2. Queue作成前の確認事項

- [x] Master Planは承認済みである。
- [x] `ws001p003`が完了し、I/O cycle、wait、High-Z、世代profileを利用できる。
- [x] 初期targetは386以降、旧世代はrecord-onlyとする判断が計画へ反映済みである。
- [x] `ws002p001`が完了し、共通IPとboard topを分離する方針が固定済みである。
- [x] ユーザが直前に提示した`ws003p001`の次Queue実行を明示的に指示した。
- [x] 調査は時間制限なしである。
- [x] `iverilog` 12.0と`vvp` 12.0が利用できる。
- [x] ユーザがQueue完了時または切りのよい境界でのcommitと`git push origin master`を許可した。

## 3. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws003p001` | [phase.md](ws003-target-bridge/phase001-bfm-target-mvp/phase.md) | completed | 2026-09-01 user requested execution of the next Queue |

## 4. 前Queue

- `Q20260831-001`: `ws001p001` completed、Queue finished。
- `Q20260831-002`: `ws001p002` uncleared、Queue finished。34 GPIOでは16-bit以上が不足し、構成選択を`ws002p001`へ差し戻した。
- `Q20260831-003`: `ws002p001` completed、Queue finished。初回Primer、将来Megaを推奨し、その後ユーザが両board topを共通IPへ接続する方針を決定した。
- `Q20260831-004`: `ws001p002-resume` completed、Queue finished。共通69 endpointをPrimer/Megaへ割り当てた。
- `Q20260831-005`: `ws001p003` completed、Queue finished。9世代profile、93 timing parameter、6 cycle contractを作成した。

## 5. 実行結果

`ws003p001` completed。

- board非依存の一件outstanding `cbus_req/cbus_rsp` handshakeを定義した。
- 2段strobe同期、mid-cycle arm防止、8/16-bit byte-enable、read OE、IORDY、timeout、reset/platform abortを持つ最小target engineを実装した。
- ID=`0xcb98`、version=`0x0001`、byte-write対応scratch、sticky status CSRを実装した。I/O base `0x00d0`はシミュレーション仮値である。
- tri-state DB BFMとmonitorにより、contention、driven X、write中drive、reset/not-ready出力を検査した。
- 386以降profileのno-wait read 239 ns、IORDY assertion 80 ns、Low幅40 ns～7 us、read hold 5 nsの境界をassertした。
- fixed/byte-lane read、16/8-bit scratch、非選択、不正lane、同時read/write、backend error、wait/timeout、platform abort、reset abort、復旧を検証した。

検証結果:

- `run_iverilog.sh`: Icarus Verilog 12.0、SystemVerilog 2012、warningなし、deterministic `SEED=1`、157 checks PASS。
- `validate_timing_contract.py`: 9 profile、93 parameter、34 step/6 cycle PASS。
- `validate_signal_matrix.py`: 100 Cバスpin、24 translator group、8 I/O profile PASS。
- `validate_platform_maps.py`: Primer/Mega mappingとI/O budget回帰PASS。
- `validate_pinouts.py`: Primer 204端子/86 GPIO、Mega 280端子/144 GPIO PASS。

成果物: [`cbus_req/cbus_rsp`契約](ws003-target-bridge/cbus-req-rsp-contract.md)、[BFM実行手順](ws003-target-bridge/tests/README.md)、`rtl/cbus/cbus_target_engine.sv`、`rtl/cbus/cbus_target_regs.sv`。

Queue内の許可作業を検証まで完了した。AXI、CDC、memory cycle、IRQ、DMA、board top、constraint、回路図、PCB、実機試験は実施していない。

## 6. 今回の実行内容

実行内容:

- board非依存の`cbus_req/cbus_rsp` handshakeとbyte-enable契約を定義する。
- CバスI/O strobeを内部clockへ同期し、read data OE、IORDY OE、reset/config gateを持つ最小target engineを実装する。
- ID、version、scratch、statusの最小register targetを実装する。
- tri-state data busを使うBFMとmonitorで8/16-bit、奇偶lane、wait、timeout、非選択、無効lane、reset abort、contention/Xを検査する。
- iverilog 12.0で再現可能な実行script、seed、test一覧、VCD出力を記録する。
- M/W/P/Qを実績へ同期する。

状態: 完了。
