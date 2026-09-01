# CバスFPGAボード Queue Book

最終更新: 2026-09-01

Queue ID: `Q20260901-011`

Queue status: finished

Parent: [master plan](master.md)

## 1. 現在の実行許可

2026-09-01にユーザが、前Queueのhandoffで提示した`ws005p001`へ続けて進むよう明示的に指示した。

mailbox、doorbell、interrupt routerのボード非依存レジスタ契約を固定する。物理CバスI/O base、IRQ番号、RISC-Vコア、RTL実装、回路図、PCB、実機は含めない。

## 2. Queue作成前の確認事項

- [x] Master Planは承認済みである。
- [x] `ws003p006`でSystem CSRとCバスからのAXI4-Lite読書きが成立した。
- [x] Mailboxは`0x1000_3000-0x1000_3fff`、interrupt routerは`0x1000_2000-0x1000_2fff`の予約案を使用する。
- [x] 物理IRQ/I/Oポートは未決定のまま、相対契約だけを完成できる。
- [x] ユーザがQueue境界でのcommitと`git push origin master`を許可している。

## 3. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws005p001` | [phase.md](ws005-mailbox-interrupt/phase001-register-contract/phase.md) | completed | 2026-09-01 user requested proceeding |

## 4. 前Queue

- `Q20260831-001`〜`Q20260901-009`: WS001/WS002/WS003の調査、Cバスtarget、CDC、AXI guard、portable topを実行。
- `Q20260901-010`: `ws003p006` completed。共通IP内にAXI4-Lite System CSRを統合した。

## 5. 今回の実行内容

- host、CPU、DMA、user IPのevent sourceと通知先を定義する。
- AXI4-Lite register map、所有者、reset、副作用を固定する。
- FIFO境界、doorbell coalescing、W1C/mask、同時set/clear/resetの決定表を作る。
- 物理baseを固定しないCバス最小相対エイリアスを定義する。
- 機械可読正本とSV/C/Rust定数の生成・照合を検証する。
- M/W/P/Qを実績へ同期する。

状態: 完了。

## 6. 実行結果

`ws005p001` completed。

- H2C/C2H各8-entry×32-bit FIFO、独立doorbell、CPU/host別interrupt bankのABI v1を固定した。
- 31 AXI4-Lite register、17 event source、16のCバス相対aliasを定義した。
- FIFOのempty/middle/full同時push/pop、overflow/underflow、reset競合を決定表で一意にした。
- pendingはmask中も保持、W1Cとset同時はset優先、repeated doorbellはcoalesced stickyとした。
- CバスI/O baseとIRQ番号を未決定のまま、32-byte相対aliasとpolling operationを完成した。
- JSON正本からSystemVerilog、C、Rust定数を生成・照合するツールと生成物を追加した。
- AXI4-Liteにmanager identityがないため、owner制限をCバスalias/将来interconnectの責務とする境界を明記した。
- 後続`ws005p002`のstandalone RTL Phase Bookを実行可能な粒度で作成した。
- ユーザが購入したx86ラボ`CB-U04`を初回ユニバーサル基板候補としてM書/WS008へ記録した。

検証結果:

- Mailbox ABI/schema/generator: PASS (31 registers、17 events、16 aliases)。
- SystemVerilog generated constants: 12 checks PASS。
- C generated header: 12 compile-time checks PASS。
- 既存HDL regression: WS003 656 + WS002 3377 = 4033 checks PASS。
- WS001 signal/platform、WS002 pinout/constraint/portable structure validator: PASS。
- Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でwarningなし。C11は`-Wall -Wextra -Werror`でPASS。

物理IRQ番号、CバスI/O base、RISC-Vコア、mailbox/router RTL、共通IP統合は本Queueに含めていない。
