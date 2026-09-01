# CバスFPGAボード Queue Book

最終更新: 2026-09-01

Queue ID: `Q20260901-013`

Queue status: proposed; awaiting user authorization

Parent: [master plan](master.md)

## 1. Queue proposal

`ws004p001`だけを実行し、ユーザ設計RISC-VコアをSoCへ差し替える外部I/O契約、safe stub、port validator、自己検査BFMを作る。

ユーザはRISC-Vコア内部を自分で設計し、プロジェクト側にはAXI4・割り込みその他の必要port詳細化とstub作成を求めた。本Queueはそのうち、依存がなく単独検証できるcore slot境界だけを有限範囲にする。

## 2. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws004p001` | [phase.md](ws004-soc-runtime/phase001-riscv-soc-requirements/phase.md) | pending | awaiting explicit approval of this Queue proposal |

## 3. Included

- 単一32-bit AXI4 Managerの全AW/W/B/AR/R port、parameter、対応subsetを契約化する。
- software/timer/external interruptのactive-high level入力を契約化する。
- clock、active-Low reset、enable、boot address、hart ID、sleep/halted/trap diagnosticを契約化する。
- 全AXI request/responseをinactiveに保つ`riscv_core_ip_stub`を実装する。
- module/port/width/constantを検査するvalidatorとIcarus自己検査BFMを追加する。
- stub使用時にCPU unavailableと扱うintegration checklistを記録する。
- 既存WS002/WS003/WS005回帰と構造validatorを再実行する。
- 実行結果をM/W/P/Qへ同期し、切れ目でcommit/pushする。

## 4. Excluded

- ユーザ所有RISC-V coreのpipeline、ISA、CSR/trap、cache、debug、toolchain、firmware。
- AXI interconnect、AXI4-to-AXI4-Lite bridge、timer/software-interrupt CSR、boot ROM。
- `ws005p004` Cバスrange-write frontendのRTL。P書の詳細化まで済んでいるが、`ws003p004/ws005p005`未完のため今回Queueへ入れない。
- Primer DDR/Gowin primitive、回路図、PCB、実機。

## 5. Dependencies and uncertainty

- user coreはまだ存在しなくてもstubとport manifestだけで完了できる。
- 初期fabric保証はread/write各1 outstanding、INCR burst、32-bit dataとする。user coreが複数Manager、coherency、より多いoutstanding、NMI/debug pinを必須とする場合はABIを推測変更せず`uncleared`として判断点を記録する。
- stubは機能CPUではなく、RISC-V bootやfirmware testを成功扱いにしない。

## 6. Completion decision

[ws004p001 Phase Book](ws004-soc-runtime/phase001-riscv-soc-requirements/phase.md)のcompletion conditionsを満たし、新規validator/BFMと既存回帰がPASSした場合に`completed`とする。合理的に完了できない場合は理由、得られたinterface情報、再開条件を記録して`uncleared`とする。

## 7. Authorization boundary

このQ書は提案であり、まだRTL実装を許可しない。ユーザが`Q20260901-013`または`ws004p001`の実行を明示承認した後に、Queue statusをrunningへ変更して着手する。
