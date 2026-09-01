# CバスFPGAボード Queue Book

最終更新: 2026-09-01

Queue ID: `Q20260901-012`

Queue status: finished

Parent: [master plan](master.md)

## 1. 今回の実行許可

`ws005p002`のstandalone mailbox FIFO / interrupt router RTLと自己検査BFMを実装する。実CPU、物理CバスIRQ、I/O base、共通IP統合に依存しない範囲だけを対象とする。

2026-09-01にユーザが前Queue終了後の次候補`ws005p002`へ「続けてください」と指示し、Queue案提示後に「実行をお願いします」と明示承認した。

## 2. Queue作成前の確認事項

- [x] Master Planは承認済みである。
- [x] `ws005p001`でABI v1の31 register、17 event source、FIFO/同時操作規則が固定済みである。
- [x] `ws003p006`でAXI4-Lite subordinate実装とBFMの参照構造が存在する。
- [x] 物理IRQ/I/O baseを決めずにstandalone RTLの完了条件を検証できる。
- [x] Primer 20K primary / Mega 138K IP referenceの方針に影響しないboard-independent Phaseである。
- [x] ユーザがQueue境界でのcommitと`git push origin master`を許可している。

## 3. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws005p002` | [phase.md](ws005-mailbox-interrupt/phase002-mailbox-router-rtl/phase.md) | completed | 2026-09-01 user explicitly approved execution |

## 4. 実行する範囲

- depth 8、width 32のH2C/C2H FIFO、staging、peek/pop、occupancy/error stickyを実装する。
- 32-source CPU/host interrupt router、mask、W1C、set-wins、valid-source maskを実装する。
- doorbell pending/coalescingとmailbox eventからrouter sourceへの接続を実装する。
- AW/W独立受理、WSTRB、B/R backpressure、`SLVERR`/`DECERR`を含むAXI4-Lite subordinateを実装する。
- FIFO全状態のpush/pop、pending/mask/W1C/set/reset衝突、doorbell/error、AXI protocolの自己検査BFMを追加する。
- ABI生成照合、WS002/WS003 HDL回帰、WS001/WS002 validatorを再実行する。
- 実績と検証数をM/W/P/Qへ同期する。

## 5. 対象外

- `cbus_ip_top`とAXI fabricへの統合。
- Cバス32-byte相対alias decoder、物理I/O base、IRQ番号、IRQ OE/極性。
- RISC-Vコア、firmware、PC-98診断プログラム。
- DMA/user IP本体、回路図、PCB、Gowin合成、実機試験。

## 6. 主な依存関係と不確実性

- 正本は`mailbox-register-map.json`と`mailbox-interrupt-contract.md`であり、ABI変更は本Queueで行わない。
- AXI manager identityがないためowner制限は後続interconnect/aliasの責務とし、standalone subordinateは全registerを同一のAXI portへ公開する。
- 同一clock domain内で実装し、非同期event/FIFO化は必要になった後の別Phaseとする。
- 契約に矛盾が見つかった場合はRTL側で推測せず、`ws005p001`改定の判断点として`uncleared`へ戻す。

## 7. 完了判定

[ws005p002 Phase Book](ws005-mailbox-interrupt/phase002-mailbox-router-rtl/phase.md)のCompletion conditionsを満たし、新規と既存の全回帰がPASSした場合に`completed`とする。合理的に完了できない場合は、理由と再開条件を記録して`uncleared`とする。

## 8. 実行結果

`ws005p002` completed。

- 8-entry×32-bitの同期FIFO coreを実装し、empty/middle/fullのpush/pop同時操作とset-wins stickyを固定した。
- Mailboxとinterrupt routerを別のAXI4-Lite subordinate moduleにし、二つのportとevent接続を持つstandalone subsystemを実装した。
- ABI v1の31 register、H2C/C2H ordering、overflow/underflow、W1C/mask/set-wins、doorbell coalescing、AW/W独立受理、B/R backpressure、`SLVERR`/`DECERR`、reset/recoveryを検証した。
- Mailboxのerror stickyとrouter pending、doorbell pendingとcoalesced stickyを別々にclearできることを確認した。
- 生成済みABI packageのbase、ID/CAP、valid-source mask、event maskをRTLが直接参照する。
- 物理IRQ、I/O base、Cバスalias、RISC-V、共通IP統合は対象外のままである。

検証結果:

- 新規WS005 HDL: 116 checks PASS。
- 既存WS003/WS002 HDL: 656 + 3377 checks PASS。HDL合計4149 checks PASS。
- ABI/schema/generator: PASS。SV/C定数は各12 checks PASS。
- WS001 signal/platform、WS002 pinout/constraint/portable-top validator: PASS。
- Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でwarningなし。

次は`ws005p005`を実行可能なP書へ詳細化し、AXI fabric、Cバス相対alias、`cbus_ip_top`統合を別Queueとして提案する。
