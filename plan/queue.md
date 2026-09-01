# CバスFPGAボード Queue Book

最終更新: 2026-09-01

Queue ID: `Q20260901-008`

Queue status: finished

Parent: [master plan](master.md)

## 1. 現在の実行許可

2026-09-01にユーザが、直前のhandoffで次候補として提示した`ws003p003`への進行を明示的に指示した。

`ws003p003`として、単一許可regionのAXI4-Lite guard、local DECERR、bounded timeout、assert済みtransactionのquarantine、明示的fault clear、sticky/first-fault record、board非依存wrapperをiverilogで実装・検証する。汎用interconnect、System CSR/IRQ配線、AXI4 Full、メモリcycle、DMA、board top、constraint、回路図、PCB、実機試験は含めない。

## 2. Queue作成前の確認事項

- [x] Master Planは承認済みである。
- [x] `ws003p002`が完了し、Cバス/CDC/AXI4-Lite Managerと非同期BFMを利用できる。
- [x] Cバス由来ManagerをPC-98 host apertureへ再入させない方針がMaster Planで固定済みである。
- [x] Cバスtimeoutより短い下流timeoutと、受理済みAXI transactionのcoherent reset境界が必要と判明している。
- [x] ユーザが直前に提示した`ws003p003`への進行を指示した。
- [x] 調査は時間制限なしである。
- [x] `iverilog` 12.0と`vvp` 12.0が利用できる。
- [x] ユーザがQueue完了時または切りのよい境界でのcommitと`git push origin master`を許可した。

## 3. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws003p003` | [phase.md](ws003-target-bridge/phase003-axil-guard-timeout/phase.md) | completed | 2026-09-01 user requested proceeding to the next Queue |

## 4. 前Queue

- `Q20260831-001`: `ws001p001` completed、Queue finished。
- `Q20260831-002`: `ws001p002` uncleared、Queue finished。34 GPIOでは16-bit以上が不足し、構成選択を`ws002p001`へ差し戻した。
- `Q20260831-003`: `ws002p001` completed、Queue finished。初回Primer、将来Megaを推奨し、その後ユーザが両board topを共通IPへ接続する方針を決定した。
- `Q20260831-004`: `ws001p002-resume` completed、Queue finished。共通69 endpointをPrimer/Megaへ割り当てた。
- `Q20260831-005`: `ws001p003` completed、Queue finished。9世代profile、93 timing parameter、6 cycle contractを作成した。
- `Q20260901-006`: `ws003p001` completed、Queue finished。CバスI/O target MVPと157-checkのBFMを作成した。
- `Q20260901-007`: `ws003p002` completed、Queue finished。dual-clock CDCとAXI4-Lite bridgeを合計467 checksで検証した。

## 5. 実行結果

`ws003p003` completed。

- System CSR 4 KiBだけを許可するAXI4-Lite region guardを実装し、PC-98 memory/I/O host apertureを含む範囲外accessを下流handshakeなしのlocal DECERRにした。
- 上流AW/Wを独立bufferし、両方が揃ってからaddress判定と下流forwardを行う。
- AXI VALIDはREADY前にも取消せないという実装時発見をP書へ戻し、handshake前を含む全timeoutをquarantineする設計へ修正した。
- timeout後も未handshake VALID/payloadを保持し、遅延B/Rをdrainする。fault中の新規requestは保存payloadを上書きせずlocal DECERRにする。
- subordinate/interconnect reset後の`fault_clear`だけで再開し、`fault_reset_req`をreset controller向けに出力する。
- guard/timeout/downstream-error stickyとfirst-fault code/direction/addressを実装し、status clearとfault clearを分離した。
- 既存Cバス/CDC/AXI subsystemへguardを追加するboard非依存wrapperを実装した。

検証結果:

- 既存`tb_cbus_target_mvp` 157、`tb_async_fifo` 57、`tb_cbus_axil_bridge` 253 checks PASS。
- `tb_axil_guard_timeout`: region reject、first fault、SLVERR、issue/partial/response timeout、VALID/payload保持、fault中payload非上書き、late drain、reset/clear/recoveryの65 checks PASS。
- `tb_cbus_guarded_axil`: 通常CSR、guard timeoutがCバスtimeoutより先に返ること、fault中local error、下流reset後復旧、coherent resetの103 checks PASS。
- Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でwarningなし。合計635 checks PASS。
- WS001 timing/signal/platform validatorとWS002 pinout validatorはすべてPASS。

成果物: [AXI4-Lite guard契約](ws003-target-bridge/axil-guard-contract.md)、[実行手順](ws003-target-bridge/tests/README.md)、`rtl/axi/axil_guard_timeout.sv`、`rtl/cbus/cbus_target_guarded_axil_subsystem.sv`、二つの自己検査BFM。

Queue内の許可作業を検証まで完了した。fault recordは安定したsidebandまでを実装し、System CSR/IRQ配線はWS005/WS004との後続境界へ残した。汎用複数target interconnect、メモリcycle、board top、constraint、回路図、PCB、実機試験は実施していない。

## 6. 今回の実行内容

実行内容:

- single-region AXI4-Lite guardとlocal DECERRを実装する。
- AXI VALID保持則に従い、handshake前を含む全下流timeoutをquarantineする。
- fault中local error、late response drain、fault reset/clear境界を実装する。
- sticky原因とfirst-fault code/direction/addressを記録する。
- 既存subsystemへguardを接続するboard非依存wrapperと自己検査BFMを追加する。
- 既存467 checksとWS001/WS002 validatorを回帰する。
- M/W/P/Qを実績へ同期する。

状態: 完了。
