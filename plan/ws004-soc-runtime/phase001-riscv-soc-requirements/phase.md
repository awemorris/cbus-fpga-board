# ws004p001: ユーザ設計RISC-Vコア外部interface・stub

最終更新: 2026-09-01

WSID: `ws004`

Phase ID: `p001`

Combined ID: `ws004p001`

Status: completed

Parent: [WS004](../ws.md)

## User decision

RISC-Vコア内部はユーザが設計する。エージェントはpipeline、decoder、ALU、register file、CSR/trap内部、ISA拡張、core用toolchain、既存core比較を設計しない。本Phaseはユーザ実装コアを差し替え接続する外部I/O契約と、無動作stubだけを作る。

## Objective

ユーザ設計RISC-VコアとCバスFPGA SoCの間に、board/DDR/vendor非依存の固定port ABIを用意する。単一32-bit AXI4 Manager、machine-mode割り込み、clock/reset/enable、boot/hart情報、最小diagnosticを定義し、コア内部を知らずにSoC fabricとIcarus回帰を構築できるようにする。

## Ownership boundary

User-owned core:

- 命令fetchとdata accessを一つのAXI4 Managerへ調停する処理。
- ISA、pipeline、CSR、trap entry/return、割り込みmask/priority、WFI。
- AXI errorをinstruction/load/store access faultへ変換する処理。
- cache、misaligned access、debugを実装する場合のcore内部方針。

Project-owned wrapper/SoC:

- AXI4 interconnect、address decode、AXI4-Lite bridge、guard/timeout。
- boot ROM、BRAM/behavioral memory、後段のDDR target。
- software interrupt、timer interrupt、32-source external interrupt router。
- core reset sequencing、memory map、status収集、stub/BFM/validator。
- Cバスwrite-event frontend。これはcore pinを増やさずexternal interruptへ集約する。

coreはCバスpin、Primer/Mega名、Gowin primitive、mailbox event IDを直接持たない。

## Fixed module parameters and non-AXI I/O

stub module名は`riscv_core_ip_stub`、ユーザ差替えmoduleの契約名は`riscv_core_ip`とする。両者のparameter/port ABIをvalidatorで照合する。

| Name | Dir | Width | Meaning |
| --- | --- | ---: | --- |
| `core_clk_i` | in | 1 | coreとCPU AXI Managerの共通clock。 |
| `core_rst_n_i` | in | 1 | active-Low core reset。assert中は全AXI VALID/READYとdiagnostic pulseをinactiveにする。 |
| `core_enable_i` | in | 1 | 1で実行許可。0はidle時の新規transaction禁止。緊急停止にはresetを使う。 |
| `boot_addr_i` | in | 32 | reset解除時にsampleする最初のfetch address。 |
| `hart_id_i` | in | 32 | platformが与えるhart ID。初期SoCは0固定。 |
| `irq_software_i` | in | 1 | machine software interrupt pending (`MSIP`) level。 |
| `irq_timer_i` | in | 1 | machine timer interrupt pending (`MTIP`) level。 |
| `irq_external_i` | in | 1 | machine external interrupt pending (`MEIP`) level。 |
| `core_sleep_o` | out | 1 | WFI等のsleep level。clock停止要求として直接使わない。 |
| `core_halted_o` | out | 1 | reset/disable/debug等でinstructionを進めない観測level。 |
| `core_trap_valid_o` | out | 1 | trap entryの一clock diagnostic pulse。未実装coreは0固定可。 |
| `core_trap_cause_o` | out | 32 | trap cause snapshot。未実装coreは0固定可。 |
| `core_trap_pc_o` | out | 32 | trap前PC snapshot。未実装coreは0固定可。 |

`boot_addr_i`と`hart_id_i`は`core_rst_n_i=0`中から安定させ、core実行中に変更しない。NMI、debug request、vector ID、`mtime[63:0]`入力は初期ABIに含めない。timer値はproject-owned MMIO timerから読む。

## AXI4 Manager port

一つの32-bit AXI4 Managerを`m_axi_*` prefixで公開する。初期parameter:

| Parameter | Default | Constraint |
| --- | ---: | --- |
| `AXI_ADDR_WIDTH` | 32 | 初期ABIでは32固定。 |
| `AXI_DATA_WIDTH` | 32 | 初期ABIでは32固定、`WSTRB`は4 bit。 |
| `AXI_ID_WIDTH` | 2 | ID 0〜3。stubは0固定、初期fabricは少なくともread/write各1 outstandingを受理する。 |

公開channel:

```text
AW: m_axi_awid_o, awaddr_o, awlen_o, awsize_o, awburst_o,
    awlock_o, awcache_o, awprot_o, awqos_o, awvalid_o, awready_i
 W: m_axi_wdata_o, wstrb_o, wlast_o, wvalid_o, wready_i
 B: m_axi_bid_i, bresp_i, bvalid_i, bready_o
AR: m_axi_arid_o, araddr_o, arlen_o, arsize_o, arburst_o,
    arlock_o, arcache_o, arprot_o, arqos_o, arvalid_o, arready_i
 R: m_axi_rid_i, rdata_i, rresp_i, rlast_i, rvalid_i, rready_o
```

WidthはAXI4に従い、ID=`AXI_ID_WIDTH`、address=32、LEN=8、SIZE=3、BURST=2、LOCK=1、CACHE/QOS=4、PROT=3、data=32、WSTRB=4、RESP=2とする。USER/REGION channelは初期ABIへ含めない。

### Supported AXI subset

- `INCR` burstだけを必須とし、`FIXED/WRAP`は発行しない。
- 1、2、4-byte beatを許し、4-byte wordを基本とする。transactionは4 KiB boundaryを跨がない。
- `AWLOCK/ARLOCK=0`。exclusive/locked accessとatomic extensionは初期対象外。
- AXI4-Lite CSR/MMIOへのaccessはsingle beat (`LEN=0`, `LAST=1`) とする。
- instruction fetchは`ARPROT[2]=1`、data/MMIOは`AxPROT[2]=0`として区別する。
- `VALID`とpayloadは`READY` handshakeまで不変。response READYをassertした後はhandshakeまで保持する。
- write address/dataの独立handshakeを許容し、B response前にwrite完了とみなさない。
- `BRESP/RRESP=SLVERR/DECERR`をcore内部で該当access faultへ変換する。
- 初期fabric保証はread/write各1 outstandingである。より多いoutstandingや複数IDを要求するuser coreは、p002詳細化前に上限を申告する。
- reset assert中は`AWVALID/WVALID/ARVALID/BREADY/RREADY=0`。coherent SoC resetで未完transactionを破棄し、reset前responseを新しい実行へ適用しない。

## Interrupt pins

必須interruptはRISC-V machine-mode pending classへ対応するactive-high同期level三本だけとする。

| Pin | Source outside core | Hold/clear rule |
| --- | --- | --- |
| `irq_software_i` | AXI4-Lite software-interrupt CSR | firmwareがCSRをclearするまでHigh。 |
| `irq_timer_i` | timer/compare block | compare条件解除または再設定までHigh。 |
| `irq_external_i` | `mailbox_interrupt_subsystem.cpu_irq_active` | routerの有効pending sourceをW1CするまでHigh。 |

- 三入力は`core_clk_i`へ同期済みのlevelであり、pulseを直接入力しない。
- mailbox、guard、DMA、Cバスwrite event、user IPの個別sourceは32-source routerへlatchし、一本の`irq_external_i`へ集約する。
- core内部の`mie/mip/mstatus/mtvec`、priority、trap entry/returnはuser-ownedである。
- 外部routerのevent IDはcore port ABIへ露出しない。firmwareがAXI4-Lite pending/active CSRを読む。
- reset中に外部pendingは保持可能であり、core resetでCバス/mailbox/routerをclearしない。

## Stub behavior

`rtl/cpu/riscv_core_ip_stub.sv`は全portを宣言し、次の無動作状態を保つ。

- 全AXI request VALID、BREADY、RREADYを0。
- address/data/control/IDを0、`WLAST=0`。
- `core_sleep_o=0`、`core_halted_o=1`。
- trap diagnosticを0。
- AXI input、interrupt、boot/hart入力に依存してside effectを起こさない。

stubは機能coreの代替ではなく、SoC port/elaboration/safe-default回帰専用である。stubを使うbuildはSystem CSR capabilityにCPU unavailableを表示し、RISC-V動作試験をPASS扱いにしない。

## Required outputs

- `riscv-core-interface.md`: parameter、全port、AXI subset、interrupt/reset/diagnostic契約の正本。
- `rtl/cpu/riscv_core_ip_stub.sv`: 上記のcompile/elaboration stub。
- `tests/validate_riscv_core_interface.py`: module名、parameter、port名、方向、width、stub safe constantsを検査する。
- `tests/tb_riscv_core_ip_stub.sv`: reset/enable/IRQ/AXI inputを変化させても無動作であることをIcarus検査する。
- p002/p004へ渡すintegration checklist。

## Excluded

- user RISC-V core内部RTLとそのtestbench。
- AXI interconnect、timer/software-interrupt CSR、boot ROM、firmware実装。
- Cバスwrite-event frontend本体（`ws005p004`）。
- Gowin DDR/PLL、Primer pin、Mega carrier、PCB、実機。
- core ISA、privilege level、cache、debug、license、toolchainの選定。

## Work packages

- [x] interface正本とAXI signal tableを作る。
- [x] `riscv_core_ip_stub`を実装する。
- [x] port/schema validatorとstub BFMを追加する。
- [x] stubを使ったcompile/elaboration手順をWS004 testsへ用意する。
- [x] CPU unavailable capabilityとp002/p004 integration entry条件を記録する。
- [x] M/W/P/Qへ結果を同期する。

## Verification plan

- SystemVerilog 2012、Icarus Verilog 12.0、`-Wall -Wimplicit`でwarningなし。
- reset、enable、boot/hart、三IRQ、全AXI inputを変化させてもstubがrequest/responseを受理せず、safe outputを維持する。
- AXI4全channelの方向/widthと、`AXI_ADDR/DATA/ID_WIDTH` parameter整合をvalidatorで検査する。
- user差替えmodule用port manifestとstubが一致する。
- 既存WS002 portable topとWS003/WS005 HDL回帰に影響がない。

## Completion conditions

- ユーザcoreが同じ外部I/Oを実装すれば、内部設計を変更・公開せずSoCへ差し替えられる。
- AXI4、software/timer/external IRQ、reset/enable、boot/hart、diagnosticの意味が一意である。
- coreがCバス、Gowin、board、mailbox event IDへ依存しない。
- stubがsafe-defaultでelaborateし、validator/BFM/既存回帰がPASSする。
- core内部仕様や実装を決めずに完了できる。

## Interruption and resume policy

- user coreが複数AXI Manager、ACE/coherency、複数outstanding必須等を必要とする場合は、p002実装前にadapterまたはABI改定としてユーザへ戻す。
- NMI/debug/vector-ID pinが必要になった場合は用途と互換性を示し、portを黙って追加しない。
- core内部仕様が必要になった場合は本Phaseを拡大せず、ユーザ提供仕様を待つ。

## Execution result

2026-09-01 Queue `Q20260901-013`で完了。

- ABI v1.0を単一32-bit AXI4 Manager、software/timer/external IRQ、clock/reset/enable、boot/hart、sleep/halted/trap diagnosticとして固定した。
- machine-readable manifestは50 portsを、control 5、interrupt 3、status 5、AW 11、W 5、B 4、AR 11、R 6へ分類する。
- `AXI_ADDR_WIDTH=32`、`AXI_DATA_WIDTH=32`、`AXI_ID_WIDTH=2`の3 parameterを固定した。
- `riscv_core_ip_stub`は入力値にかかわらずAXI VALID/READYを0、payloadを0、haltedだけを1に保つ。stub buildはCPU unavailableであり、boot成功を表さない。
- interface正本、CSV manifest、module/width/constant validator、Icarus BFM、再現scriptを追加した。
- Cバスrange-write frontendはcore ABIへ混ぜず、依存後の`ws005p004`へ残した。

再現コマンド:

```sh
plan/ws004-soc-runtime/tests/run_iverilog.sh
```

結果:

```text
tb_riscv_core_ip_stub: PASS: 30 checks
PASS: RISC-V core slot ABI 50 ports / 3 parameters
```

Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でcompile warningなし。WS002 3377、WS003 656、WS005 116の既存HDL checksもPASSし、HDL合計4179 checksとなった。mailbox ABIのSV/C 24 checks、WS001 signal/platform/timing、WS002 pinout/portable-top validatorもPASSした。
