# ws005p001: メールボックス・割り込みレジスタ契約

最終更新: 2026-09-01

WSID: `ws005`

Phase ID: `p001`

Combined ID: `ws005p001`

Status: planned; dependency satisfied by `ws003p006`

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

- [ ] host、CPU、DMA、user IPのイベント一覧と優先度を作る。
- [ ] register mapと状態遷移図を作る。
- [ ] W1C、mask、同時set/clear、FIFO境界の決定表を作る。
- [ ] PC-98 I/O窓に公開する最小subsetを定義する。
- [ ] RTLテストとsoftware driverが共有できる定数生成方針を決める。

## Completion conditions

- 全レジスタにoffset、幅、reset値、アクセス権、副作用、所有者がある。
- 同一サイクルのset/clear、mask切替、overflow、reset競合の結果が一意である。
- PC-98とCPUのどちらが何をclearするかが一意で、IRQ stormを避けられる。
- 将来のRTL、C header、Rust/C driver定数を一つの正本から生成または照合できる。

## Expected evidence

register map、状態遷移、イベント一覧、レビュー結果、未決のIRQ/ポート選択を記録する。

## Interruption and resume record

Not started. IRQ共有規則またはポート競合の判断が必要なら、相対契約だけを完成させ、物理割当を `uncleared` としてユーザ判断へ戻す。
