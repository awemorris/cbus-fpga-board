# ws005p005: Cバスmailbox alias・AXI decode・共通IP統合

最終更新: 2026-09-01

WSID: `ws005`

Phase ID: `p005`

Combined ID: `ws005p005`

Status: completed

Parent: [WS005](../ws.md)

## Objective

`ws005p002`のstandalone mailbox/interrupt subsystemをboard-independent `cbus_ip_top`へ統合し、物理I/O baseとIRQ番号を未決定のまま、Cバスのparameterized 32-byte aliasからhost所有のmailbox/router操作とpollingを検証できるようにする。

## Dependencies and source contracts

- [`ws005p001` mailbox/interrupt contract](../mailbox-interrupt-contract.md): 16 aliasの番地、slice、所有者、副作用。
- [`mailbox-register-map.json`](../mailbox-register-map.json): AXI block base/register/event定数の正本。
- [`ws005p002`](../phase002-mailbox-router-rtl/phase.md): 検証済みのFIFO、mailbox、router、二AXI subordinate port。
- [`ws003p002` CDC/AXI契約](../../ws003-target-bridge/cdc-axil-contract.md): Cバスrequest、tag、lane、timeout後の遅延response隔離。
- [`ws003p003` AXI guard契約](../../ws003-target-bridge/axil-guard-contract.md): region制限、timeout、quarantine、fault clear。
- [`ws003p006` System CSR](../../ws003-target-bridge/phase006-system-csr/phase.md): 既存Cバス8-byte窓と`0x1000_0000`の四word。

上記のABIや同時操作規則は本Phaseで変更しない。矛盾が見つかった場合はブリッジ内で推測せず、契約改定の判断点として本Phaseを`uncleared`に戻す。

## Scope

- System CSR用8-byteとmailbox用32-byteの二つのCバスI/O apertureを認識するtarget decode。
- 16個のCバス相対aliasを実AXI registerとlow/high halfへ変換するbridge。
- `HOST_DIAG_STATUS`の三read合成と`HOST_DIAG_ACK`の最大三write展開。
- CバスManager一つからSystem CSR、interrupt router、mailboxの三targetへ振り分けるAXI4-Lite decoder。
- `mailbox_interrupt_subsystem`を`cbus_ip_top`内へ統合し、guard faultの新規assertをCPU event bit 6へ一サイクルpulseで接続する。
- CバスhostからのH2C push/doorbellと、C2H/pending/error/doorbellのpolling経路。
- alias無効時の既存System CSR回帰と、alias有効の単体/統合BFM。

## Excluded

- 実機で使うCバスI/O base、decode jumper/DIP/software設定の決定。
- 物理CバスIRQ番号、極性、共有条件、OE、LVC配線、実機割り込み試験。
- RISC-Vコア、firmware/ISR、PC-98診断プログラム。
- 二つ以上のAXI Managerの調停、一般化したSoC fabric、DDR/DMA/user IP統合。
- Gowin合成、回路図、PCB、実機。

## Fixed safe parameters

`cbus_ip_top`からboard wrapperへ次を追加する。

| Parameter | Safe default | Meaning |
| --- | ---: | --- |
| `CBUS_MBX_ENABLE` | `1'b0` | 0でmailbox物理apertureをdecodeせず、既存System CSRのみ有効。 |
| `CBUS_MBX_IO_BASE` | `16'h0000` | enable時の32-byte aligned test/physical base。`0000`は無効時のplaceholderであり割当済みを意味しない。 |

32-byte decode maskはmodule内の`16'hffe0`固定値とし、board parameterにしない。ABI v1のalias aperture幅をbuildごとに変えないためである。

alias enable時は次のelaboration assertionを必須とする。

- `CBUS_MBX_IO_BASE[4:0] == 0`。
- mailbox 32-byte窓とSystem CSR 8-byte窓が重ならない。
- AXI guardのallow条件が`0x1000_0000-0x1000_3fff`を含む。alias無効時は既存`0x1000_0000-0x1000_0fff`のままでよい。

Primer/Mega board topと`cbus_board_shell`は同じparameterを透過させる。両wrapperの安全な既定値はalias disabledとし、実I/O base選定前のbitstreamが新たなportに応答しないことを保つ。Megaは論理referenceのみであり、物理board supportを復活させない。

## Architecture

```text
C-bus I/O cycle
       |
       v
cbus_target_engine
  sys-select: 8 bytes
  mbx-select: 32 bytes, parameterized and default-disabled
       |
       v
req/rsp CDC + tag quarantine
       |
       v
cbus_to_axil_bridge
  system linear mapping
  mailbox alias mapping / slice / compound diagnostic command
       |
       v
AXI guard (all generated transactions remain guarded)
       |
       v
axil_control_fabric_1x3
  0x1000_0xxx -> axil_system_csr
  0x1000_1xxx -> local DECERR
  0x1000_2xxx -> axil_interrupt_router
  0x1000_3xxx -> axil_mailbox
```

`axil_control_fabric_1x3`はCバスManager専用の一Manager/三target decoderである。将来CPUとの調停を本moduleに推測実装せず、複数Manager fabricはWS004統合時の別Phaseにする。

## Alias translation table

BFMとRTLは`cbus_mailbox_regs_pkg.sv`の生成定数を使う。ハードコードした別register mapを作らない。

| Cバスoffset | Alias operation | AXI operation | Read result / write transform |
| ---: | --- | --- | --- |
| `+0x00` | `H2C_LO` | `MBX_H2C_HOST_LO_ADDR` | low 16 / `WSTRB[1:0]=BE` |
| `+0x02` | `H2C_HI` | `MBX_H2C_HOST_HI_ADDR` | low 16 / `WSTRB[1:0]=BE` |
| `+0x04` | `H2C_PUSH` | `MBX_H2C_HOST_PUSH_ADDR` | low 16 / W1P bit 0 |
| `+0x06` | `H2C_DOORBELL_SET` | `MBX_H2C_DOORBELL_SET_ADDR` | low 16 / W1S bit 0 |
| `+0x08` | `H2C_STATUS_LO` | `MBX_H2C_STATUS_ADDR` | AXI `[15:0]` |
| `+0x0a` | `H2C_STATUS_HI` | `MBX_H2C_STATUS_ADDR` | AXI `[31:16]` |
| `+0x0c` | `C2H_LO` | `MBX_C2H_HOST_LO_ADDR` | AXI `[15:0]` |
| `+0x0e` | `C2H_HI` | `MBX_C2H_HOST_HI_ADDR` | AXI `[15:0]` |
| `+0x10` | `C2H_POP` | `MBX_C2H_HOST_POP_ADDR` | low 16 / W1P bit 0 |
| `+0x12` | `C2H_STATUS_LO` | `MBX_C2H_STATUS_ADDR` | AXI `[15:0]` |
| `+0x14` | `C2H_STATUS_HI` | `MBX_C2H_STATUS_ADDR` | AXI `[31:16]` |
| `+0x16` | `HOST_PENDING` | `INTR_HOST_PENDING_ADDR` | AXI `[15:0]` |
| `+0x18` | `HOST_MASK` | `INTR_HOST_MASK_ADDR` | low 16 / `WSTRB[1:0]=BE` |
| `+0x1a` | `HOST_ACK` | `INTR_HOST_ACK_ADDR` | low 16 / W1C |
| `+0x1c` | `HOST_DIAG_STATUS` | 三AXI read | H2C overflow→bit0、C2H underflow→bit1、C2H coalesced→bit2 |
| `+0x1e` | `HOST_DIAG_ACK` | 0〜三AXI write | input bits 2:0を三のW1C registerへ展開 |

8-bit odd-address accessは対応wordの`BE[1]`/AXI `WSTRB[1]`とする。bit 0〜2だけを持つW1P/W1S/compound commandへupper byteのみをwriteした場合は副作用なしの`OKAY`とし、不正に別bitを発火させない。実AXI subordinateが返す`SLVERR`/`DECERR`、またはcompound operation中のいずれかのerrorは、Cバスresponse全体のerrorとする。compound sequenceは最初のerrorで打ち切り、guard quarantine中に後続transactionを発行しない。

### `HOST_DIAG_STATUS`

次の順にAXI readし、一つの16-bit Cバスresponseへ合成する。

1. `MBX_H2C_STATUS_ADDR[16]` → result bit 0。
2. `MBX_C2H_STATUS_ADDR[17]` → result bit 1。
3. `MBX_DOORBELL_STATUS_ADDR[17]` → result bit 2。

三readの間は元のCDC request/tagを保持し、中間値をCバス側へ返さない。スナップショット原子性は保証しない。sticky値なので、合成中の0→1は次回pollで必ず観測できる。

### `HOST_DIAG_ACK`

lower byte enableがある場合だけinput bits 2:0を解釈し、setされたbitのみ次の順でwriteする。

1. bit 0: `MBX_H2C_HOST_ERR_ACK_ADDR`へ`0x0001_0000`, `WSTRB=0100`。
2. bit 1: `MBX_C2H_HOST_ERR_ACK_ADDR`へ`0x0002_0000`, `WSTRB=0100`。
3. bit 2: `MBX_DOORBELL_COALESCED_ACK_ADDR`へ`0x0002_0000`, `WSTRB=0100`。

write bitが0の場合は対応AXI transactionを省略する。全3bitが0、またはlower byte disableなら、AXI transactionを発行せずCバスへ正常完了を返す。

## AXI decoder contract

`axil_control_fabric_1x3`は次を満たす。

- AWとWを独立に一件ずつbufferし、AW addressでtargetを確定してから両channelを同じsubordinateへ渡す。
- ARを一件bufferし、RVALID/RDATA/RRESPをManagerのRREADYまで保持する。
- Writeとreadは独立state machineとし、それぞれ最大一outstandingとする。
- `0x1000_0xxx`、`0x1000_2xxx`、`0x1000_3xxx`以外は下流VALIDを出さずlocal `DECERR`を返す。
- responseは発行したtargetからだけ受理し、非選択targetのREADY/VALIDを混線しない。
- Reset中は下流とCバスへVALID/responseを残さない。

## Event and IRQ boundary

- `guard_faulted` 0→1の同期pulseをCPU event bit 6 `GUARD_FAULT`へ接続する。fault levelを連続setしない。
- DMAとUSER IRQ eventは本Phaseで0に固定し、実装済みと表示しない。
- `cbus_ip_top`は論理状態として`mailbox_cpu_irq_active`と`mailbox_host_irq_active`を観測出力する。board shellは現Phaseでこれらを物理pinへ接続しない。
- `cbus_irq_assert=0`、`lvc_irq_oe_req=0`の既存安全状態を維持する。host pending/maskが1でも物理CバスIRQを駆動しない。

## Expected implementation files

Existing files to update:

- `rtl/cbus/cbus_target_engine.sv`
- `rtl/axi/cbus_to_axil_bridge.sv`
- `rtl/cbus/cbus_target_axil_subsystem.sv`
- `rtl/cbus/cbus_target_guarded_axil_subsystem.sv`
- `rtl/ip/cbus_ip_top.sv`
- `rtl/platform/cbus_board_shell.sv`
- `rtl/top/tang_primer20k_top.sv`
- `rtl/top/tang_mega138k_top.sv` (IP reference parameter propagation only)
- `plan/ws002-fpga-platform/tests/run_iverilog.sh`
- `plan/ws003-target-bridge/tests/run_iverilog.sh`
- `plan/ws005-mailbox-interrupt/tests/run_iverilog.sh`

New files:

- `rtl/axi/axil_control_fabric_1x3.sv`
- `plan/ws005-mailbox-interrupt/tests/tb_cbus_mailbox_alias_bridge.sv`
- `plan/ws005-mailbox-interrupt/tests/tb_axil_control_fabric_1x3.sv`
- `plan/ws005-mailbox-interrupt/tests/tb_cbus_mailbox_alias_top.sv`

実装中にこれより大きなモジュール分割が必要と判明した場合は、P書を黙って拡大せず新しいPhaseへ戻す。

## Work packages

- [x] Cバスtargetにdefault-disabledの第二32-byte aperture decodeと非重複assertionを追加する。
- [x] `cbus_to_axil_bridge`へ16 alias、low/high slice、compound diagnostic sequenceを追加する。
- [x] 一Manager/三target AXI4-Lite decoderを実装する。
- [x] mailbox/router subsystem、guard fault event、logical IRQ観測を`cbus_ip_top`へ統合する。
- [x] alias parameterをshell/Primer primary/Mega reference topへ同じsafe defaultで透過させる。
- [x] alias bridge、AXI decoder、Cバスtop統合の自己検査BFMを追加する。
- [x] ABI生成照合、WS002/WS003/WS005回帰、WS001/WS002 validatorを実行する。
- [x] 結果、check数、残る物理判断をM/W/P/Qへ同期する。

## Verification plan

### Alias bridge BFM

- alias無効時のSystem CSR四word変換が既存と同一である。
- 16 aliasすべてのAXI address、read half、write data/strobe、owner公開範囲がJSON生成定数と一致する。
- 8/16-bit lane、odd address、nonselected address、RO write、downstream `SLVERR`/`DECERR`が一意になる。
- `HOST_DIAG_STATUS`は三read後に一responseを返し、中間のbackpressure/error/resetで不正な中間応答を返さない。
- `HOST_DIAG_ACK`は0、1、複数、3bit全の各パターンを正しい順で展開する。

### AXI decoder BFM

- AW-first、W-first、同時write、B backpressure、AR/R backpressureを三targetすべてで検査する。
- target間のready/response混線がなく、`0x1000_1xxx`と範囲外は下流無駆動のlocal `DECERR`となる。
- Resetが保持中transactionとresponseを消去する。

### Integrated Cバス/IP-top BFM

BFM専用に`CBUS_MBX_ENABLE=1`、実機割当とは明示的に異なる32-byte aligned test baseを使う。

- 既存System CSR ID/version/scratch/statusが不変である。
- CバスからH2C low/high staging、push、occupancy、doorbellを操作し、FIFOとlogical CPU pending/IRQ activeへ到達する。
- C2H/status/pending/diagnostic aliasのaddress/sliceはalias bridge BFMとstandalone mailbox BFMの証拠を組み合わせて確認する。実CPUをこのPhaseのために追加しない。
- alias無効時とnonselected/gap addressでdata OE、IORDY OE、IRQ OEを誤assertしない。
- Standalone router BFMと構造検査を組み合わせ、host logical IRQが物理`cbus_irq_assert`/`lvc_irq_oe_req`へ未接続であることを確認する。実CPUのC2H doorbellをtop BFMのために仮実装しない。
- 異なるCバス/AXI clock、AXI backpressure、guard error/timeout/quarantine、reset/platform abort後の復帰を検査する。

### Regression commands

Repository rootから少なくとも次を実行する。

```sh
plan/ws005-mailbox-interrupt/tests/run_iverilog.sh
plan/ws005-mailbox-interrupt/tests/run_contract_checks.sh
plan/ws003-target-bridge/tests/run_iverilog.sh
plan/ws002-fpga-platform/tests/run_iverilog.sh
python3 plan/ws001-cbus-contract/tests/validate_signal_matrix.py
python3 plan/ws001-cbus-contract/tests/validate_platform_maps.py
python3 plan/ws002-fpga-platform/tests/validate_pinouts.py
python3 plan/ws002-fpga-platform/tests/validate_portable_top.py
```

Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でwarningなしを必須とする。

## Completion conditions

- Safe defaultでmailbox Cバスapertureが無効であり、既存System CSR、Primer primary top、Mega reference topの論理回帰が不変である。
- BFM enable時に16 aliasのaddress/slice/side effectとcompound diagnostic operationが契約どおりである。
- 全Cバス由来AXI transactionがguardを通過し、decoderの未実装regionはlocal `DECERR`となる。
- H2C data→push→doorbell→CPU pendingと、host polling/ackの論理経路がCバスtop BFMで再現できる。
- AXI VALID payloadはREADYまで不変、compound中間responseは外へ漏れず、timeout/reset後に無限待ちがない。
- logical IRQは観測できるが、物理CバスIRQ/OEは本Phase後も0/High-Z側である。
- ABI/schema/generator、WS002/WS003/WS005 HDL回帰、WS001/WS002 validatorがすべてPASSする。
- 実CバスI/O base、IRQ番号、RISC-Vを未決定のまま完了できる。

## Execution result

2026-09-01 Queue `Q20260901-014`で完了した。

- `CBUS_MBX_ENABLE=0`をsafe defaultとする第二32-byte apertureを追加した。enable時はbaseの32-byte整列、System CSR窓との非重複、guardが`0x1000_0000-0x1000_3fff`を許可しhost apertureを拒否することをelaboration時に検査する。
- `cbus_to_axil_bridge`へ生成ABI定数を使う16 alias、status upper/lower slice、W1P upper-byte no-op、`HOST_DIAG_STATUS`三read、`HOST_DIAG_ACK`最大三writeを実装した。compound sequenceは一件ずつ発行し、最初のAXI errorで停止する。
- `axil_control_fabric_1x3`を実装し、System CSR、interrupt router、mailboxへread/writeを独立にrouteする。`0x1000_1xxx`と範囲外は下流無駆動のlocal DECERRとした。
- `cbus_control_subsystem`でSystem CSRと既存standalone mailbox/routerを統合し、guard fault 0→1をCPU event bit 6へ一pulseで接続した。logical CPU/host IRQは`cbus_ip_top`から観測できるが、物理`cbus_irq_assert`と`lvc_irq_oe_req`は0のままである。
- alias無効buildは既存System CSRへ直結するgenerate branchとし、従来の応答latencyとsafe-default回帰を変更しない。Primer/Mega wrapperは同じdisabled defaultとparameterを透過する。
- 新規BFMはalias bridge 150 checks、1×3 decoder 20 checks、Cバス共通IP統合41 checksをPASSした。既存FIFO/router 116 checksを含むWS005合計は327 checksである。
- WS003 656、WS002 3377、WS004 30を合わせた現在のHDL合計は4390 checksである。mailbox ABI v1の31 registers、17 events、16 aliases、SV/C各12 checks、WS001/WS002のsignal/platform/timing/pin/portable-top validatorもPASSした。

実I/O base、物理IRQ番号/OE/LVC、CPU/firmware、複数Manager fabric、Gowin合成、回路図、PCB、実機は実装していない。

## Interruption and resume policy

- 実I/O baseやIRQ番号を決めないとRTL/BFMが完成できないと判明した場合は、テスト用parameterで補わず判断点を記録する。
- compound aliasに一般的な複数Manager仲裁が必要と判明した場合は、WS004/SoC fabricの新Phaseへ戻す。
- 既存ABI変更、物理IRQ駆動、CPU/firmware実装は本Phaseを拡大せず、別のユーザ承認Queueへ戻す。
