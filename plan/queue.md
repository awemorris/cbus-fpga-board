# CバスFPGAボード Queue Book

最終更新: 2026-08-31

Queue ID: `Q20260831-005`

Queue status: finished

Parent: [master plan](master.md)

## 1. 現在の実行許可

2026-08-31にユーザが、直前のhandoffで次候補として提示した`ws001p003`のQueue実行を明示的に指示した。

`ws001p003`として、PC-9800シリーズの受動Cバスターゲットに必要なI/O read/write、memory read/write、IRQ/INTA、IORDY wait、世代別クロック条件を一次資料から契約化する。DMA、外部CPU/DMA、bus-master、RTL、BFM、constraint、回路図、PCB、実機測定は含めない。

## 2. Queue作成前の確認事項

- [x] Master Planは承認済みである。
- [x] `ws001p001`、`ws001p002`、`ws002p001`は完了し、信号台帳と一次資料が利用できる。
- [x] ユーザがV13固有ではなくPC-9800シリーズ全般を互換目標とした。
- [x] ユーザが直前に提示した`ws001p003`の次Queue実行を明示的に指示した。
- [x] 調査は時間制限なしである。
- [x] ユーザがQueue完了時または切りのよい境界でのcommitと`git push origin master`を許可した。

## 3. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws001p003` | [phase.md](ws001-cbus-contract/phase003-timing-contract/phase.md) | completed | 2026-08-31 user requested execution of the next Queue |

## 4. 前Queue

- `Q20260831-001`: `ws001p001` completed、Queue finished。
- `Q20260831-002`: `ws001p002` uncleared、Queue finished。34 GPIOでは16-bit以上が不足し、構成選択を`ws002p001`へ差し戻した。
- `Q20260831-003`: `ws002p001` completed、Queue finished。初回Primer、将来Megaを推奨し、その後ユーザが両board topを共通IPへ接続する方針を決定した。
- `Q20260831-004`: `ws001p002-resume` completed、Queue finished。共通69 endpointをPrimer/Megaへ割り当てた。

## 5. 実行結果

`ws001p003` completed。

- 8086-class、70116系、80286/386、486/Pentiumを9個のtiming profileへ分離した。
- S001のI/O/memory/read/write/IORDY/IRQから93個のparameterをsource page付きで機械可読化した。
- I/O read/write、memory read/write、IRQとINTA境界を34 step、6 cycle contractへ変換した。
- 80286 12 MHzではSCLKがCPUと非同期でtiming基準にできないため、共通targetをSCLK同期だけで設計しない契約とした。
- IORDYはtri-state Low wait、Low幅40 ns以上7 us以下、後期共通入力ではassert deadline最大80 ns、release setup 30 ns（XA 37 ns）とした。
- IRQはpositive edge要求までを確定し、資料が定量規定しないLow pulse幅とV13挙動は未確認として残した。
- INTA0は受動cardへのackではなく外部CPU用信号のため`ws001p004`へ送った。
- ユーザ判断により初期targetを386以降とし、8086/70116/80286固有profileはrecord-onlyへ分類した。S001上の486/Pentiumは同じ後期型cycle familyのparameter差として扱い、不連続が後続資料/実測で見つかった場合を再検討境界とした。

検証結果:

- `validate_timing_contract.py`: 9 profile、93 parameter、34 step/6 cycle PASS。
- `validate_signal_matrix.py`: 100 Cバスpin、24 translator group、8 I/O profile PASS。
- `validate_platform_maps.py`: Primer/Mega mappingとI/O budget回帰PASS。
- `validate_pinouts.py`: Primer 204端子/86 GPIO、Mega 280端子/144 GPIO PASS。

成果物: [タイミング契約](ws001-cbus-contract/timing-contract.md)、[世代profile](ws001-cbus-contract/timing-profiles.csv)、[定量parameter](ws001-cbus-contract/timing-parameters.csv)、[cycle契約](ws001-cbus-contract/cycle-contract.csv)。

Queue内の許可作業を検証まで完了した。RTL、BFM、constraint、回路図、PCB、実機測定は実施していない。

## 6. 今回の実行内容

実行内容:

- S001の該当ページと波形注記を画像で照合する。
- 世代profileを分離し、定量値を単位・source・確度付きで機械可読化する。
- I/O read/write、memory read/write、IRQ/INTA、IORDYの開始、sample/drive、wait、終了、release条件を記録する。
- 資料が規定しない内部サンプリング余裕や実機差は未確認として分離する。
- 自動検査でsignal matrix参照、cycle coverage、profile、単位、source、statusを確認する。
- M/W/P/Qを実績へ同期する。

状態: 完了。
