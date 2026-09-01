# ws003p003: AXI4-Lite region guard・timeout・fault記録

最終更新: 2026-09-01

WSID: `ws003`

Phase ID: `p003`

Combined ID: `ws003p003`

Status: completed

Parent: [WS003](../ws.md)

## Scope

`ws003p002`のCバス由来AXI4-Lite Managerと下流AXI4-Lite subordinate/fabricの間へ、単一許可region、local DECERR、bounded timeout、fault quarantine、first-fault recordを持つboard非依存保護層を追加する。

## Goal

禁止address、下流backpressure、部分的write handshake、response無応答、下流AXI errorを決定的に終了・記録し、Cバスを永久waitさせず、受理済みtransactionの遅延responseを後続transactionへ誤適用しない安全な復旧境界を得る。

## Preconditions and decisions

- Cバス側timeoutは既定6 usである。AXI guard timeoutはそれより短く設定し、通常はguard error responseをCバス側へ返す。
- 既定許可regionはSystem CSR予約領域`0x1000_0000-0x1000_0fff`とする。
- `0x8000_0000-0x80ff_ffff`および`0x8100_0000-0x8100_ffff`のPC-98 host apertureはCバス由来Managerから禁止する。
- AXI4-Liteではassert済みAWVALID/WVALID/ARVALIDをhandshake前にも取り下げられない。下流handshakeの有無にかかわらず、すべてのtimeoutでguardをquarantineし、未handshakeのvalid/payloadを保持する。
- 下流reset完了後の明示的`fault_clear`までdownstream portを再利用しない。
- fault中の新規requestは下流へ出さずlocal DECERRで終了する。
- first-fault recordはstatus clearまで保持し、quarantine clearとは分離する。

## Non-goals

- 複数AXI targetを束ねる汎用interconnect、AXI4 Full、burst、複数outstanding
- 下流IP固有reset controller、PLL/DDR reset、board top、Gowin primitive
- System CSRへのfault register実配線、IRQ生成、ファームウェア
- Cバスメモリcycle、DMA、bus master、回路図、PCB、実機試験

## Implementation approach

- `axil_guard_timeout`がupstream AW/Wをbufferし、両方揃ってからaddress判定と下流forwardを行う。
- readはARをbufferしてaddress判定後にforwardする。
- 許可外は下流validを一度も出さず`DECERR`、timeoutは`SLVERR`を返す。
- AW/Wの片方だけを含む下流受理済みtimeoutもquarantineする。
- quarantine中は未handshake valid/payloadを保持し、遅延B/Rをdrainする。新規requestへはbufferを上書きせずlocal DECERRを返し、`fault_reset_req`を継続assertする。
- sticky guard/timeout/downstream-errorと、最初のcode/write/addressをsideband出力する。
- `cbus_target_guarded_axil_subsystem`で既存subsystemのAXI出力へ保護層を接続する。

## Work packages

- [x] region decode、AW/W buffer、read/write responseを持つAXI4-Lite guardを実装する。
- [x] issue/response timeoutと全timeoutのquarantineを実装する。
- [x] quarantine、late response drain、fault reset/clear handshakeを実装する。
- [x] sticky原因とfirst-fault recordを実装・契約化する。
- [x] 既存Cバス/CDC subsystemへguardを追加するboard非依存wrapperを実装する。
- [x] standalone AXI BFMとCバス統合BFMでguard、timeout、quarantine、復旧を検証する。
- [x] 既存467 checksとWS001/WS002 validatorを回帰する。

## Completion conditions

- 許可regionだけが下流へforwardされ、host apertureを含む禁止addressは下流handshakeなしでDECERRになる。
- AW/W/ARのhandshake前timeoutでもassert済みvalid/payloadを保持してquarantineする。
- 一部または全部を下流が受理後にtimeoutした場合もquarantineし、後続requestを下流へ出さない。
- fault中requestはlocal DECERRで終了し、下流coherent reset後の`fault_clear`で正常復旧する。
- downstream SLVERR/DECERR、guard reject、timeoutの原因・direction・addressがfirst-fault/stickyへ記録される。
- guard timeoutがCバスtimeoutより先に応答し、CバスIORDYを永久保持しない。
- Icarus Verilog 12.0でwarningなしにcompileでき、自己検査と既存回帰がPASSする。

## Verification evidence

実行script、deterministic test一覧、check数、VCD、compile warning、既存回帰結果を`tests/`と本書へ記録する。一時生成物は`temp/`へ置く。

## Interruption and resume record

2026-09-01 Queue `Q20260901-008`で完了。実装中に、AXI VALIDはREADY handshake前にも取り下げられないため「未受理timeoutの自動復旧」は不正と判明した。全timeoutをquarantineし、未handshake valid/payloadを下流resetまで保持する契約へ修正した。

fault recordのSystem CSR/IRQ配線と複数target interconnectはWS005/WS004との境界を要するため、このPhaseではsideband contractまでとした。

## Execution result

- `axil_guard_timeout`に単一許可region、AW/W独立buffer、local DECERR、issue/response timeoutを実装した。
- assert済みAW/W/ARはhandshakeまたはcoherent resetまでvalid/payloadを保持する。全timeoutでquarantineし、`fault_reset_req`をassertする。
- fault中の新規requestは保存payloadを上書きせずlocal DECERRにし、遅延B/Rは下流側でdrainする。
- subordinate/interconnect reset後にidle状態で`fault_clear`を受けた場合だけ保存transactionとquarantineをclearする。
- guard reject、timeout、downstream errorのstickyと、code/direction/addressのfirst-fault recordを実装した。`status_clear`と`fault_clear`は分離した。
- `cbus_target_guarded_axil_subsystem`で既存Cバス/CDC/AXI bridgeへguardを追加した。
- [AXI4-Lite guard契約](../axil-guard-contract.md)にregion、timeout、復旧順序、fault codeを記録した。

再現コマンド:

```sh
plan/ws003-target-bridge/tests/run_iverilog.sh
```

結果:

```text
tb_cbus_target_mvp: PASS: 157 checks
tb_async_fifo: PASS: 57 checks
tb_cbus_axil_bridge: PASS: 253 checks
tb_axil_guard_timeout: PASS: 65 checks
tb_cbus_guarded_axil: PASS: 103 checks
total: 635 checks
```

Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でcompile warningなし。既存WS001/WS002 validatorもすべてPASSした。VCDとcompiled simulationは`plan/ws003-target-bridge/temp/iverilog/`へ生成しGit管理外とした。
