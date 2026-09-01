# CバスFPGAボード Queue Book

最終更新: 2026-09-01

Queue ID: `Q20260901-014`

Queue status: finished

Parent: [master plan](master.md)

## 1. Queue proposal

`ws005p005`だけを実行し、standalone mailbox/interrupt subsystemをboard-independent `cbus_ip_top`へ統合する。default-disabledのparameterized Cバス32-byte alias、16 alias変換、compound diagnostic operation、CバスManager専用1×3 AXI4-Lite decoder、guard fault event、logical IRQ観測を実装・検証する。

ユーザは2026-09-01に「`ws005p005`を実行します」と指示した。今回のtimeboxは、このセッションで合理的に完了または`uncleared`判定までとする。

## 2. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws005p005` | [phase.md](ws005-mailbox-interrupt/phase005-cbus-alias-integration/phase.md) | completed | 2026-09-01 user explicitly approved execution |

## 3. Included

- System CSR 8-byte窓とdefault-disabled mailbox 32-byte窓を認識するCバスtarget decode。
- 16 relative alias、low/high slice、`HOST_DIAG_STATUS`三read、`HOST_DIAG_ACK`最大三writeの変換。
- CバスManager一つからSystem CSR、interrupt router、mailboxへ振り分ける1×3 AXI4-Lite decoder。
- mailbox/router subsystem、guard fault event bit 6、logical CPU/host IRQの`cbus_ip_top`統合。
- alias parameterのboard shell、Primer primary top、Mega reference topへのsafe-default透過。
- alias bridge、decoder、共通IP統合の自己検査BFM。
- ABI生成照合、WS002/WS003/WS005回帰、WS001/WS002 validator。
- 実行結果のM/W/P/Q同期と、完了境界でのcommit/push。

## 4. Excluded

- 実機用CバスI/O base、decode jumper/DIP/software設定。
- 物理CバスIRQ番号、極性、共有、OE、LVC配線、実機IRQ試験。
- RISC-V core、firmware/ISR、PC-98診断プログラム。
- 複数AXI Managerの仲裁、一般SoC fabric、DDR/DMA/user IP統合。
- Gowin合成、回路図、PCB、実機。

## 5. Dependencies and uncertainty

- `ws005p001/p002`のABI v1、`ws003p002/p003`のCDC/guard契約、`ws003p006`のSystem CSR契約を変更しない。
- alias enable時だけguard許可範囲を`0x1000_0000-0x1000_3fff`へ広げ、host apertureは引き続き禁止する。
- compound operationが既存一件outstanding契約を超える一般仲裁を必要とする場合は、Phaseを拡大せず`uncleared`として判断点を記録する。
- logical host IRQがpendingでも物理`cbus_irq_assert`と`lvc_irq_oe_req`は0を維持する。

## 6. Completion decision

[ws005p005 Phase Book](ws005-mailbox-interrupt/phase005-cbus-alias-integration/phase.md)のcompletion conditionsを満たし、指定されたABI/HDL/validator回帰がPASSした場合に`completed`とする。合理的に完了できない場合は理由、保存した成果、再開条件を記録して`uncleared`とする。

## 7. Authorization boundary

2026-09-01にユーザが「`ws005p005`を実行します」と指示し、本Queueの実行を承認した。

## 8. Execution result

`ws005p005` completed。

- Cバスtargetへsafe-default disabledの32-byte mailbox apertureとalignment/non-overlap assertionを追加した。
- 生成ABIに基づく16 alias、low/high slice、三read diagnostic status、最大三write diagnostic acknowledgeを実装した。
- CバスManager専用1×3 AXI4-Lite decoderと`cbus_control_subsystem`を追加し、System CSR、interrupt router、mailboxを共通IPへ統合した。
- guard fault 0→1をCPU event bit 6へ接続し、logical CPU/host IRQを観測可能にした。物理CバスIRQ/OEは0を維持した。
- alias無効buildは従来System CSRへ直結し、Primer/Mega wrapperのsafe defaultと既存応答を不変にした。
- 新規alias bridge 150、decoder 20、top統合41 checksを追加した。WS005は既存116を含む327 checks、全HDLはWS002 3377、WS003 656、WS004 30と合わせて4390 checksをPASSした。
- mailbox ABI v1の31 registers、17 events、16 aliases、SV/C各12 checks、WS001/WS002 signal/platform/timing/pin/portable-top validatorがすべてPASSした。
- 実I/O base、物理IRQ番号/OE/LVC、RISC-V/firmware、複数Manager fabric、Gowin合成、回路図、PCB、実機は後続Phaseへ残した。
