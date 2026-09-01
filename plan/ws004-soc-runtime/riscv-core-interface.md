# RISC-V core slot external interface contract

最終更新: 2026-09-01

Contract version: `1.0`

Owner Phase: [`ws004p001`](phase001-riscv-soc-requirements/phase.md)

Machine-readable port source: [`riscv-core-port-manifest.csv`](riscv-core-port-manifest.csv)

## 1. Boundary and module selection

RISC-V core内部はユーザ所有である。project側はcoreの外側にAXI fabric、memory、AXI4-Lite peripherals、interrupt source、reset sequencingを置く。

- User implementation module: `riscv_core_ip`
- Safe compile/elaboration module: `riscv_core_ip_stub`
- Stub source: `rtl/cpu/riscv_core_ip_stub.sv`

SoC buildは二moduleの一方だけを選択し、両方を同時に機能coreとして扱わない。integration wrapperは同じparameter、port名、方向、widthを接続する。stub buildはCPU unavailableであり、boot/firmware試験を成功扱いにしない。

## 2. Parameters

| Parameter | Value | Contract |
| --- | ---: | --- |
| `AXI_ADDR_WIDTH` | 32 | 初期ABIで変更不可。 |
| `AXI_DATA_WIDTH` | 32 | 初期ABIで変更不可。 |
| `AXI_ID_WIDTH` | 2 | ID 0〜3を表現。初期fabric保証はread/write各1 outstanding。 |

user coreが別値、複数Manager、ACE/coherencyを必要とする場合は、実装を接続する前にABI改定を行う。

## 3. Clock, reset, enable and identity

- `core_clk_i`はcoreとCPU AXI4 Managerの唯一のclockである。
- `core_rst_n_i`はactive Low。project reset controllerが非同期assert、`core_clk_i`同期deassertを保証する。
- reset中、coreは全AXI `VALID`と`READY`出力、trap pulseを0にする。
- `core_enable_i=0`では新規transactionを開始しない。通常停止はoutstanding=0で行い、緊急中断はcoherent resetを使う。
- `boot_addr_i`と`hart_id_i`はreset中から安定し、実行中に変更しない。
- reset解除後、enableされたuser coreは`boot_addr_i`から最初のinstruction fetchを開始する。
- core resetはCバスtarget、mailbox、interrupt routerのpendingをclearしない。

初期reference SoCは`hart_id_i=0`とする。boot addressの数値はboot ROM mapを凍結するPhaseで決定する。

## 4. AXI4 Manager

port prefixは`m_axi_`、address/data widthは32 bitである。AW/W/B/AR/Rの全signalとdirection/widthはport manifestを正本とする。

### Required subset

- `INCR` burstのみ。`FIXED`と`WRAP`を発行しない。
- beat sizeは1、2、4 byte。4 KiB boundaryを跨がない。
- AXI4-Lite peripheral accessはsingle beat (`AxLEN=0`, `xLAST=1`)。
- exclusive/locked accessを発行せず、`AWLOCK=ARLOCK=0`。
- instruction fetchは`ARPROT[2]=1`、data/MMIO readは`ARPROT[2]=0`。
- writeはdata accessなので`AWPROT[2]=0`。
- `VALID`とpayloadは`READY` handshakeまで不変。
- AWとWは独立にhandshakeできる。B responseまでwriteを完了扱いにしない。
- R channelは`RLAST`まで同じread transactionであり、response IDを対応requestへ照合する。
- `SLVERR`と`DECERR`はuser coreがinstruction/load/store access faultへ変換する。
- 初期fabricはread一件、write一件を同時に受理できる。複数outstandingは保証しない。
- USERとREGION signalは存在しない。

### Reset and timeout

AXI transactionはprotocol上で任意取消しできない。core、fabric、targetは同じcoherent resetで未完transactionを破棄する。fabric側guard/timeoutは有限時間でerror responseまたはcoherent reset要求を生成し、永久待ちを避ける。

## 5. Interrupt inputs

三入力は`core_clk_i`へ同期済みのactive-high levelである。

| Input | Architectural pending class | Source |
| --- | --- | --- |
| `irq_software_i` | machine software (`MSIP`) | software-interrupt AXI4-Lite CSR |
| `irq_timer_i` | machine timer (`MTIP`) | timer/compare block |
| `irq_external_i` | machine external (`MEIP`) | interrupt router `cpu_irq_active` |

source pulseはrouterまたはsource-side stickyでlevelへ変換してからcoreへ入力する。mailbox、guard、DMA、Cバスwrite event、user IPのevent IDはcore portへ展開しない。firmwareはinterrupt routerのpending/active CSRを読み、sourceを処理してW1Cする。

NMI、debug request、vector IDはABI 1.0にない。core内部のinterrupt enable、priority、trap/returnはuser-ownedである。

## 6. Diagnostic status

- `core_sleep_o`: WFI等のsleep観測。clock gateへ直結しない。
- `core_halted_o`: coreがinstructionを進めていない観測level。
- `core_trap_valid_o`: trap entry一clock pulse。
- `core_trap_cause_o`, `core_trap_pc_o`: trap pulseと同時のsnapshot。

trap diagnosticを実装しないuser coreは三trap出力を0固定できる。その場合、System CSR capabilityでtrap observation unavailableを示す。これらは制御/ack portではない。

## 7. Stub contract

`riscv_core_ip_stub`は入力値によらず次を保つ。

- AW/W/AR VALID=0、B/R READY=0。
- AXI payload、ID、address、data、control=0。
- `core_halted_o=1`、他status/trap=0。
- memory、CSR、interruptへside effectを起こさない。

stubは安全なelaboration placeholderであり、user coreの機能を模倣しない。

## 8. User core integration checklist

- module `riscv_core_ip`のport manifestがstubと一致する。
- reset/disable中のAXI outputが契約どおりinactiveである。
- AXI backpressure中にVALID payloadが変化しない。
- instruction/data/MMIOの`AxPROT[2]`が契約どおりである。
- unsupported burst/lock/outstandingを発行しない。
- AXI errorがarchitectural access faultになる。
- 三interrupt levelが対応pending CSRへ反映される。
- core reset中も外部pendingを破壊しない。
- stub sourceをuser core sourceと同時にcore slotへ選択しない。

## 9. Change control

port追加、direction/width変更、AXI subset拡大はABI変更である。NMI/debug/cache maintenance/coherency/複数Managerが必要になった場合、wrapperへ黙って配線せず新Phaseでcontract versionを更新する。
