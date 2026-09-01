# AXI4-Lite region guard・timeout・fault recovery契約

最終更新: 2026-09-01

対象Phase: [`ws003p003`](phase003-axil-guard-timeout/phase.md)

## 1. 境界

`axil_guard_timeout`はCバス由来AXI4-Lite Managerと下流subordinate/fabricの間に置く一件outstandingの保護層である。許可addressだけをforwardし、禁止access、下流timeout、AXI errorを上流へ有限時間で返して記録する。

`cbus_target_guarded_axil_subsystem`は`ws003p002`のboard非依存subsystemへこのguardを追加する。Primer/Megaのpin、PLL、DDR、Gowin primitiveを参照しない。

## 2. Region policy

既定許可region:

```text
base = 0x1000_0000
mask = 0xffff_f000
range = 0x1000_0000-0x1000_0fff
```

これはMaster PlanのSystem CSR予約領域である。region外accessは下流AW/W/ARをassertせず、read/writeとも上流へ`DECERR`を返す。

特に次のPC-98 host apertureはCバス由来Managerから禁止される。

```text
0x8000_0000-0x80ff_ffff
0x8100_0000-0x8100_ffff
```

これによりCバス受動requestがCバスmaster経路へ再入するrecursive deadlockを防ぐ。将来許可regionを増やす場合もhost apertureを同じrouteへ含めない。

## 3. Write collection

上流AWとWは独立して受理・bufferする。両方が揃うまでaddress判定と下流forwardを開始しない。下流AW/Wはそれぞれhandshakeまでvalid、address/data/strobeを保持し、両方のhandshake後にB responseを待つ。

## 4. Timeoutとquarantine

AXIでは一度assertした`AWVALID/WVALID/ARVALID`をhandshake前に取り下げられない。このため、次のいずれのtimeoutもguardをquarantineする。

- 下流AW/W/ARがREADYを返さない
- AWまたはWだけを受理して残りを受理しない
- AW/W受理後にB responseを返さない
- AR受理後にR responseを返さない

timeout時は上流へ`SLVERR`とread error data `0xffff_ffff`を返し、`faulted`と`fault_reset_req`をassertする。未handshakeのdownstream valid/payloadは保持し、受理済みtransactionの遅延B/Rは`BREADY/RREADY`でdrainする。

quarantine中の新規上流requestは保存中のdownstream payloadを上書きせず、下流へforwardせずlocal `DECERR`で終了する。

## 5. Recovery handshake

`fault_clear`だけで任意のAXI transactionを取消すことはできない。復旧順序は次の通り。

1. `fault_reset_req=1`をreset controllerが観測する。
2. 該当subordinate/interconnectをresetし、部分transaction、未応答response、内部stateを破棄する。
3. 下流READYを無効のままreset解除を安定させる。
4. guardへ1 cycle以上の`fault_clear`を入力する。
5. guardが保存valid/payloadと`faulted`をclearした後、下流READYを再度許可する。

system resetはguardと下流をcoherentにresetする。`fault_clear`はguardがupstream responseを返し終えてidleのときだけ有効で、同じcycleに新規requestを開始しない。

## 6. Fault record

sticky bit:

| Signal | Meaning |
| --- | --- |
| `guard_sticky` | 許可region外をlocal DECERRにした |
| `timeout_sticky` | issueまたはresponse timeoutが発生した |
| `downstream_error_sticky` | 下流がSLVERR/DECERRを正常responseとして返した |

first-fault record:

| Code | Name | Meaning |
| ---: | --- | --- |
| 0 | none | recordなし |
| 1 | guard | address policy reject |
| 2 | issue timeout | AW/W/AR handshake完了前のtimeout |
| 3 | active timeout | B/R response待ちtimeout |
| 4 | downstream error | 下流SLVERR/DECERR |

`fault_valid/fault_code/fault_write/fault_addr`は最初のfaultを保持する。`status_clear`はstickyとfirst-faultだけをclearし、quarantineは解除しない。`fault_clear`はquarantineを解除するがstatus recordをclearしない。sidebandをSystem CSR/IRQへ接続する作業は後続Phaseとする。

## 7. Timing relation

既定のAXI側100 MHz clockでは`AXIL_TIMEOUT_CYCLES=256`は2.56 usであり、Cバス側既定6 us timeoutより短い。clock周波数を変更するboard topは、CDC往復、guard response、LVC/配線余裕を含めてもCバスIORDY上限を超えない値を再計算する。

## 8. Safety invariants

- 禁止addressを下流へassertしない。
- downstream valid/payloadをhandshakeまたはcoherent resetまで保持する。
- timeout後にdownstream portを無条件再利用しない。
- fault中のlocal error requestで保存downstream payloadを上書きしない。
- 遅延B/Rを後続requestのresponseとして返さない。
- status clearとfault recoveryを同一操作として扱わない。
