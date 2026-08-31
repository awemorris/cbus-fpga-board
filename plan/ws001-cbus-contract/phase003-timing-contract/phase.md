# ws001p003: I/O・メモリ・割り込みタイミング契約

最終更新: 2026-08-31

Phase ID: `ws001p003`

Status: completed

Parent: [WS001](../ws.md)

## Scope

PC-9800シリーズのCバス受動ターゲットが扱うI/O read/write、memory read/write、IRQ要求と割り込み応答、IORDY waitについて、世代差を失わないタイミング契約を作る。NEC一次資料で読み取れる定量値と信号順序を機械可読化し、資料が規定しないFPGA内部サンプリング余裕や実機差は未確認として分離する。

## Non-goals

- 従来DMA、外部CPU、外部DMA、バスマスタの調停・転送契約（`ws001p004`）
- RTL、BFM、constraint、回路図、PCBの実装
- V13だけに固有のタイミングをシリーズ共通仕様とみなすこと
- 測定器なしで実機タイミング、LVC伝搬遅延、基板遅延を確定すること

## Objective

WS003のCバスターゲットBFMとRTLが、サイクル開始、address/data有効、read data drive、write data sample、wait、終了、High-Z復帰を曖昧なく実装できる入力契約を用意する。

## Completion conditions

- I/O read/write、memory read/write、IRQ/INTA、IORDYについて、適用世代、開始、sample/drive、終了、High-Z条件、根拠ページを追跡できる。
- NEC資料の定量値を単位付きで機械可読化し、推定値と混在させていない。
- 8086/70116型と80286以降型で異なるタイミングを同一profileへ潰していない。
- 未確認値と、それを確定する再開条件を明記している。
- 自動検査で参照信号、profile、単位、source、cycle coverageの整合性が通る。

## Evidence and assumptions

- 主資料は`S001`「PC-9800シリーズ テクニカルデータブック ハードウェア編 1993年」の拡張用スロットバス章とする。
- PDF表示ページと冊子ページには11ページのoffsetがある（例: PDF 314 = 冊子303）。成果物では冊子ページを正本として記録する。
- 資料の波形注記を画像で照合し、OCRだけを定量値の根拠にしない。
- 対象実機PC-9821V13は初期検証候補に留め、契約はPC-9800シリーズの世代profileで表す。

## Procedure

1. S001の信号説明、AC特性、read/write、IRQ/INTA、IORDY波形ページを特定する。
2. 定量値を`timing-parameters.csv`、サイクルの順序とdrive/sample/release条件を`cycle-contract.csv`へ記録する。
3. `timing-contract.md`に世代profile、保守的な実装境界、未確認事項をまとめる。
4. validatorを追加し、signal matrixとの参照整合性、必須cycle coverage、source/unit/statusを検査する。
5. 検証結果をM/W/P/Qへ同期する。

## Verification

```sh
python3 plan/ws001-cbus-contract/tests/validate_timing_contract.py
python3 plan/ws001-cbus-contract/tests/validate_signal_matrix.py
```

## Residual work boundary

実機でしか決まらないsetup/hold余裕、LVCを含む遅延budget、V13および他世代機の波形差は`ws001p005`へ戻す。DMA・bus-master波形は`ws001p004`で扱う。

## Execution result

2026-08-31に完了。

- 8086-class、70116系、80286/386、486/Pentiumを9 profileへ分離した。
- 約4.9152/7.9872/9.8304 MHzのSCLKと世代別read/write parameterを93行で記録した。
- 80286 12 MHzのSCLKはCPUと非同期でtiming基準にできないことを明示した。
- I/O read/write、memory read/write、IRQ、INTA境界を34 stepのcycle契約へ変換した。
- IORDYはLow幅40 ns以上7 us以下、後期共通入力ではassert deadline最大80 ns、release setup 30 ns（XA 37 ns）として記録した。
- IRQはpositive edge要求を確定したが、必要Low pulse幅は資料にないため未確認として残した。
- INTA0は受動cardのackではなく外部CPU用信号であるため`ws001p004`へ分離した。
- ユーザ判断により設計targetを386以降とし、8086/70116/80286固有profileはrecord-onlyとして保持した。S001上の486/Pentiumは後期型cycle family内のparameter差として扱う。

検証結果:

```text
PASS: 9 profiles; 93 timing parameters; 34 cycle steps; 6 cycle contracts
OK: 100 C-bus pins; 24 translator groups; 40 Tang header pins / 34 shared GPIO; 8 I/O profiles
PASS: tang_primer20k maps 69 endpoints; 17 conservative GPIO remain
PASS: tang_mega138k maps 69 endpoints; 75 conservative GPIO remain
PASS: I/O budget and platform comparison totals agree
PASS: Primer 204 pins / 86 conservative GPIO
PASS: Mega 280 pins / 144 conservative GPIO
```

RTL、BFM、constraint、回路図、PCB、実機測定は実施していない。
