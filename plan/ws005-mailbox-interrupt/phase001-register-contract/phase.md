# ws005p001: メールボックス・割り込みレジスタ契約

最終更新: 2026-09-01

WSID: `ws005`

Phase ID: `p001`

Combined ID: `ws005p001`

Status: completed

Queue: `Q20260901-011`

Parent: [WS005](../ws.md)

## Objective

通常のレジスタ読書きとイベント通知を混同せず、PC-98側とRISC-V側から同じ意味で扱えるmailbox、doorbell、interrupt registerのビット単位契約と状態遷移を定義する。

## Dependencies and fixed decisions

- AXI4-Lite mailbox予約領域は `0x1000_3000-0x1000_3FFF`。
- H2C doorbellがCPU IRQを、C2H doorbellが選択したCバスIRQ pendingを発生させる。
- pending clearはW1C、maskは別レジスタとする。
- 実際のCバスI/OベースとIRQ番号は未確定で、相対offsetとして定義する。

## Scope

- register offset、field、reset value、read/write side effect、所有者
- H2C/C2Hデータ深度または固定mailbox数
- doorbell coalescing/counter、overflow、ack、mask中イベント
- resetと同時アクセス、CPU/Cバス同時アクセスの規則
- AXI4-LiteとCバスI/O窓の対応

## Work packages

- [x] host、CPU、DMA、user IPのイベント一覧と優先度を作る。
- [x] register mapと状態遷移図を作る。
- [x] W1C、mask、同時set/clear、FIFO境界の決定表を作る。
- [x] PC-98 I/O窓に公開する最小subsetを定義する。
- [x] RTLテストとsoftware driverが共有できる定数生成方針を決める。

## Completion conditions

- 全レジスタにoffset、幅、reset値、アクセス権、副作用、所有者がある。
- 同一サイクルのset/clear、mask切替、overflow、reset競合の結果が一意である。
- PC-98とCPUのどちらが何をclearするかが一意で、IRQ stormを避けられる。
- 将来のRTL、C header、Rust/C driver定数を一つの正本から生成または照合できる。

## Expected evidence

register map、状態遷移、イベント一覧、レビュー結果、未決のIRQ/ポート選択を記録する。

## Execution result

2026-09-01 Queue `Q20260901-011`で完了した。

- H2C/C2Hをそれぞれdepth 8、width 32のFIFOとし、pushとdoorbellを分離した。
- 31 AXI4-Lite register、17 event source、16 CバスaliasのABI v1を固定した。
- Doorbellは1-bit coalescing、pendingはmaskと独立、ackはW1C、set/clear同時はset優先とした。
- FIFOのempty/fullでの同時push/pop、overflow/underflow、reset競合を決定表で一意にした。
- 物理base未決定の32-byte Cバス相対aliasにより、IRQ未割当でもpollingで完結できる契約とした。
- JSONを正本とし、SystemVerilog package、C header、Rust constantsを決定的に生成するようにした。
- AXI4-Liteにmanager identityがないため、owner制限はCバスalias/interconnectで実施し、subordinate単体はmanager種別を推測しない境界を明記した。

再現コマンド:

```sh
plan/ws005-mailbox-interrupt/tests/run_contract_checks.sh
```

結果:

```text
mailbox ABI: PASS (31 registers, 17 events, 16 C-bus aliases)
tb_mailbox_constants: PASS (12 checks)
C header: PASS (12 compile-time checks)
```

Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でwarningなし。C11は`-Wall -Wextra -Werror`でPASSした。物理IRQ番号、CバスI/O base、RISC-Vコアは意図どおり未決定のままである。
