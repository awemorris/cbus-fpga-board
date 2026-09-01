# ws003p002: CDC FIFOとAXI4-Liteブリッジ

最終更新: 2026-09-01

WSID: `ws003`

Phase ID: `p002`

Combined ID: `ws003p002`

Status: completed

Parent: [WS003](../ws.md)

## Scope

`ws003p001`の一件outstanding Cバスrequest/responseを、独立したCバス側clockとAXI側clockの間で安全に搬送し、32-bit AXI4-Lite Manager transactionへ変換するboard非依存RTLを実装する。

## Goal

非同期clock、FIFO backpressure、AXI4-Lite各channelの独立backpressure、8/16-bit byte lane、AXI error、Cバスtimeout後の遅延responseを自己検査simulationで扱える共通bridge境界を得る。

## Preconditions and decisions

- `ws003p001`のI/O cycle検出、High-Z、IORDY、timeout契約を再利用する。
- CバスI/O windowの仮baseは`0x00d0`、AXI4-Lite CSR側の仮baseは`0x1000_0000`とする。
- 各Cバス16-bit wordを1個の32-bit AXI registerへ割り当てる。Cバスoffset `+0/+2/+4/+6`はAXI offset `+0/+4/+8/+12`へ変換し、`WSTRB[1:0]`でbyte laneを表す。
- request/responseへ8-bit tagを付加する。timeout済みrequestの遅延responseは破棄し、新しいCバスcycleへ誤適用しない。
- resetはCバス側、AXI側、接続先AXI subordinateへ共通に伝播する前提とする。clock停止中resetの解除順はboard top Phaseで扱う。

## Non-goals

- AXI4 Full、burst、複数outstanding、interconnect、region guard
- AXI subordinateが永久に応答しない場合のtransaction取消しまたは下流reset
- Cバスメモリcycle、IRQ、DMA、bus master
- Primer/Mega board top、Gowin primitive、constraint、回路図、PCB、実機試験

## Implementation approach

- Gray pointerと2段pointer synchronizerを持つdual-clock FIFOをrequest/responseの双方へ使用する。
- Cバス側endpointでtagを採番し、response FIFOをdrainしながらactive tagだけをtarget engineへ渡す。
- AXI bridgeはAW/Wを独立handshakeし、BまたはR完了まで次requestを開始しない。
- AXI `SLVERR/DECERR`を`rsp_error`へ変換する。Cバス側の既存error data/stickyへ接続する。
- AXI responseがCバスtimeoutより遅れた場合も、tag照合後に古いresponseを破棄して後続requestが復旧できることを検証する。

## Work packages

- [x] generic asynchronous FIFOを実装し、独立clock、coherent reset、満杯/空/順序を検証する。
- [x] tag付きCバスrequest/response CDC endpointを実装する。
- [x] 16-bit CバスI/O requestを32-bit AXI4-Liteへ変換するbridgeを実装する。
- [x] target engine、CDC、AXI bridgeを接続するboard非依存subsystemを実装する。
- [x] 非同期clock BFMでread/write、byte lane、channel backpressure、error、timeout後の遅延response、resetを検証する。
- [x] 既存BFMとWS001/WS002 validatorを回帰し、再現手順と結果を記録する。

## Completion conditions

- request/response FIFOが順序を維持し、overflow/underflowせず、独立clock比で自己検査を通る。
- AXI AW/W/AR/B/Rの各backpressure下でCバス16-bit/low-byte/high-byteアクセスが正しいaddress/data/strobeへ変換される。
- AXI errorがCバスerror応答とsticky statusへ反映される。
- Cバスtimeout後に届く古いAXI responseが後続requestへ誤適用されず、遅延transaction完了後にbridgeが復旧する。
- resetまたはplatform disable中にCバス出力要求が出ず、CDC/AXI stateが既知状態へ戻る。
- Icarus Verilog 12.0で警告なしにcompileでき、自己検査と既存回帰がPASSする。

## Verification evidence

実行script、deterministic seed、テスト一覧、check数、VCD、compile warning、既存回帰結果を`tests/`と本書へ記録する。一時生成物は`temp/`へ置く。

## Interruption and resume record

2026-09-01 Queue `Q20260901-007`で完了。AXI subordinate無応答後も新規transactionを継続するにはsystem-level reset/timeout方針が必要なため、このPhaseではCバス解放と遅延response隔離までを実装し、下流timeout/guardは`ws003p003`へ残す。

## Execution result

- depth 4のgeneric `async_fifo`を実装した。Gray pointer、2段pointer synchronizer、full/empty backpressureを持ち、payloadはdual-port memory経由で搬送する。
- `cbus_req_rsp_cdc`がrequestへ8-bit tagを付け、response FIFOをdrainしながらactive tagだけをtarget engineへ返す。timeout済みresponseは`stale_rsp_pulse`を出して破棄する。
- `cbus_to_axil_bridge`がCバス16-bit wordを32-bit AXI4-Lite registerへ展開し、AW/Wを独立handshake、B/R errorをCバスerrorへ変換する。
- `cbus_target_axil_subsystem`にtarget engine、二つのFIFO、AXI bridgeを統合した。board名、vendor primitive、package pinを参照しない。
- `reset_sync`で外部resetを両domainへ非同期assert・2段同期deassertする。Cバス側、AXI側、subordinateはcoherent resetを必要とする。
- [CDC・AXI4-Lite契約](../cdc-axil-contract.md)にpacket、address/lane mapping、reset、timeoutと残課題を記録した。

再現コマンド:

```sh
plan/ws003-target-bridge/tests/run_iverilog.sh
```

結果:

```text
tb_cbus_target_mvp: PASS: 157 checks
tb_async_fifo: PASS: 57 checks
tb_cbus_axil_bridge: PASS: 253 checks
total: 467 checks
```

Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でcompile warningなし。既存WS001/WS002 validatorもすべてPASSした。VCDとcompiled simulationは`plan/ws003-target-bridge/temp/iverilog/`へ生成しGit管理外とした。
