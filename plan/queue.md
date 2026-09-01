# CバスFPGAボード Queue Book

最終更新: 2026-09-01

Queue ID: `Q20260901-007`

Queue status: finished

Parent: [master plan](master.md)

## 1. 現在の実行許可

2026-09-01にユーザが、直前のhandoffで次候補として提示した`ws003p002`の継続実行を明示的に指示した。

`ws003p002`として、dual-clock request/response FIFO、8-bit tagによる遅延response隔離、Cバス16-bit I/Oから32-bit AXI4-Liteへの変換、board非依存subsystemをiverilogで実装・検証する。AXI4 Full、interconnect、region guard、下流無応答からの再初期化、メモリcycle、IRQ、DMA、board top、constraint、回路図、PCB、実機試験は含めない。

## 2. Queue作成前の確認事項

- [x] Master Planは承認済みである。
- [x] `ws003p001`が完了し、CバスI/O engine、request/response契約、BFMを利用できる。
- [x] 32-bit AXI4-Liteを内部CSR境界とするMaster Planが承認済みである。
- [x] CバスとAXI clock domainをrequest/response FIFOで分離する方針が固定済みである。
- [x] ユーザが直前に提示した`ws003p002`の継続実行を指示した。
- [x] 調査は時間制限なしである。
- [x] `iverilog` 12.0と`vvp` 12.0が利用できる。
- [x] ユーザがQueue完了時または切りのよい境界でのcommitと`git push origin master`を許可した。

## 3. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws003p002` | [phase.md](ws003-target-bridge/phase002-cdc-axil-bridge/phase.md) | completed | 2026-09-01 user requested continuation of the next Queue |

## 4. 前Queue

- `Q20260831-001`: `ws001p001` completed、Queue finished。
- `Q20260831-002`: `ws001p002` uncleared、Queue finished。34 GPIOでは16-bit以上が不足し、構成選択を`ws002p001`へ差し戻した。
- `Q20260831-003`: `ws002p001` completed、Queue finished。初回Primer、将来Megaを推奨し、その後ユーザが両board topを共通IPへ接続する方針を決定した。
- `Q20260831-004`: `ws001p002-resume` completed、Queue finished。共通69 endpointをPrimer/Megaへ割り当てた。
- `Q20260831-005`: `ws001p003` completed、Queue finished。9世代profile、93 timing parameter、6 cycle contractを作成した。
- `Q20260901-006`: `ws003p001` completed、Queue finished。CバスI/O target MVPと157-checkのBFMを作成した。

## 5. 実行結果

`ws003p002` completed。

- Gray pointerと2段pointer synchronizerを持つgeneric depth-4 dual-clock FIFOを実装した。
- Cバス側で8-bit tagを付加するrequest/response CDC endpointを実装し、timeout後の遅延responseを後続cycleへ誤適用せず破棄できるようにした。
- Cバス16-bit wordを32-bit AXI4-Lite registerへ展開し、offset `+0/+2/+4/+6`を`+0/+4/+8/+12`へ変換した。
- AXI AW/Wを独立handshakeし、B/R responseと`SLVERR/DECERR`をtag付きCバスresponseへ戻すbridgeを実装した。
- target engine、CDC FIFO、AXI bridge、domain別同期resetをboard非依存`cbus_target_axil_subsystem`へ統合した。
- host strobe終了edgeでrequestを新規受理しないgateをtarget engineへ追加し、abort/timeout境界のside effect競合を縮小した。

検証結果:

- `tb_cbus_target_mvp`: 157 checks PASS。
- `tb_async_fifo`: 異なる10 ns/14 ns clock、full/empty、wrap、backpressure、coherent resetの57 checks PASS。
- `tb_cbus_axil_bridge`: address/lane変換、AW/W/AR独立backpressure、valid payload保持、AXI error、timeout後のstale response破棄と復旧、resetの253 checks PASS。
- Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でwarningなし。合計467 checks PASS。
- WS001 timing/signal/platform validatorとWS002 pinout validatorはすべてPASS。

成果物: [CDC・AXI4-Lite契約](ws003-target-bridge/cdc-axil-contract.md)、[実行手順](ws003-target-bridge/tests/README.md)、`rtl/common/async_fifo.sv`、`rtl/common/reset_sync.sv`、`rtl/cbus/cbus_req_rsp_cdc.sv`、`rtl/axi/cbus_to_axil_bridge.sv`、`rtl/cbus/cbus_target_axil_subsystem.sv`。

Queue内の許可作業を検証まで完了した。AXI subordinateが永久に無応答の場合もCバスはtimeoutで解放するが、受理済みAXI transactionはresponseまたはcoherent resetまでbridgeを占有する。下流timeout、fault target、region guard、エラー記録は`ws003p003`へ残した。

## 6. 今回の実行内容

実行内容:

- generic dual-clock FIFOとtag付きrequest/response CDC endpointを実装する。
- Cバス16-bit I/Oを32-bit AXI4-Lite Manager transactionへ変換する。
- target engine、CDC、AXI bridgeをboard非依存subsystemとして統合する。
- 非同期clock、FIFO/AXI backpressure、byte lane、AXI error、timeout後の遅延response、resetを自己検査する。
- 実行script、test一覧、VCD、check数を記録する。
- M/W/P/Qを実績へ同期する。

状態: 完了。
