# Primer 20K / Mega 138K共通IPトップ境界

決定日: 2026-08-31

状態: approved design decision; RTL未実装

## 1. 決定

Tang Primer 20KとTang Mega 138K非Proは、ボード固有top-levelを差し替えて使用する。Cバス機能、AXI subsystem、CSR、mailbox、将来のDMA/RISC-V/user IPは、ボード名やFPGA pinを持たない共通`cbus_ip_top`の下へ置く。

```text
tang_primer20k_top                 tang_mega138k_top
  physical pins / CST               physical pins / CST
  Primer clock-reset-DDR wrapper    Mega clock-reset-DDR wrapper
  LVC pin grouping + hard OE gate   LVC pin grouping + hard OE gate
                \                    /
                 +-- cbus_ip_top --+
                       |
                       +-- cbus target / AXI bridge
                       +-- CSR / mailbox / DMA
                       +-- user IP boundary
                       +-- future RISC-V subsystem
```

ビルド時に選ぶのはboard target（top-level、対応constraint、必要なplatform/vendor wrapper）だけとし、`cbus_ip_top`以下のRTL source、register map、testbenchは同一にする。共通IP内で`PRIMER`/`MEGA`の`ifdef`分岐を作らない。

## 2. Board-specific topの責務

- FPGA package pin、I/O standard、drive、slew、専用clock pinをconstraintへ割り当てる。
- Primer SO-DIMMまたはMega BTBの物理pinを、共通Cバス論理portへ対応付ける。
- Gowin PLL、clock buffer、DDR controller、IOBUFなどdevice/board固有primitiveをwrapper内へ閉じ込める。
- 外付けLVCのDIR/OE pin groupを物理配線へ対応付ける。
- `cbus_ip_top`の`oe_req`を、そのまま外部へ出さず、`platform_ready && reset_released && clock_locked && bus_permit`でgateする。
- FPGA configuration中はRTLに依存せず、LVC OE pull-up等の外付け回路でHigh-Zを保証する。
- ボード固有LED、button、UART、configuration pinは、共通diagnostic interfaceへ必要なものだけ接続する。
- DDRが異なる場合、共通IPへ同一のAXI memory target interfaceを提示する。

## 3. Board-independent `cbus_ip_top`の責務

- Cバス信号を物理pinではなく、正規化した`*_i`、`*_o`、`*_oe_req`として扱う。
- 受動target、将来のDMA/bus master、CDC、AXI bridge、CSR、mailbox、user IP境界を実装する。
- board-independent clock/reset inputと、platformから渡される`platform_ready`/capabilityを使う。
- DDR実装やGowin primitiveを直接instantiateせず、AXI memory interfaceだけを見る。
- ボード固有のGPIO本数に合わせて機能を暗黙に削らない。未対応機能は明示的なcapability parameter/constantとbuild-time assertionで拒否する。
- 共通BFMと`iverilog` testbenchから、Primer/Mega topを通さず単体検証できる。

## 4. 固定する共通境界

`ws002p002`では少なくとも次を型とport幅まで固定する。

`ws001p002`でboard-independent endpointは69本に確定し、[Primer/Mega共通mapping](../ws001-cbus-contract/platform-mapping.md)へ記録した。`ws002p002`はこの順序と`common_port`名を入力にする。

| Boundary | 内容 |
| --- | --- |
| `cbus_phy_if` | address/data/controlのinput、output、OE request。世代差は物理pin欠落ではなくcapability/decode policyで扱う。 |
| `platform_status_if` | power-good相当、clock locked、reset released、module/board ID、capability。 |
| `axi_mem_if` | board固有DDR controllerが提供する共通AXI target。DDR未使用buildでは明示的error targetへ接続する。 |
| `debug_if` | UART/diagnostic event等。物理LEDやUSB-UARTの有無を共通IPへ漏らさない。 |
| `safe_drive_if` | 共通IPの方向/OE requestと、board topが返す実drive-enabled状態。安全gateをbypassしない。 |

SystemVerilog `interface`を使うかflat port bundleにするかは、Gowin/iverilog双方でのtool compatibilityを確認して`ws002p002`で決める。論理契約はどちらでも同一にする。

## 5. 想定するsource配置

```text
rtl/
  ip/
    cbus_ip_top.sv
    cbus_subsystem/...
    axi/...
    user_ip/...
  top/
    tang_primer20k_top.sv
    tang_mega138k_top.sv
  platform/
    primer20k/...
    mega138k/...
  vendor/gowin/...
constraints/
  primer20k/*.cst
  mega138k/*.cst
sim/
  cbus_ip_top/...
```

source配置は実装Queueで作成する。現時点では計画上の境界であり、ファイルを先行生成しない。

## 6. 受入条件

- 同一の`cbus_ip_top`を変更せず、Primer/Megaの両board targetがelaborateできる。
- board名、package pin、DDR part名、PLL primitiveが`rtl/ip/`以下に現れない。
- 共通IPの自己検査testを一度実行すれば、両topで共有できる機能の論理検証になる。
- 各board topについて、reset/config/clock不成立時のLVC OEがHigh-Z側になるassertionまたは構造検査がある。
- capability差は黙ったport削除ではなく、定数、CSR、build assertionへ表れる。
- register map、firmware ABI、user IP AXI境界はboard差し替えで変わらない。

## 7. 保留事項

- 初回基板でbus-master用LVC/pinを実装済み、DNP、未配線のどれにするか。
- Primer/MegaそれぞれのDDR controllerをいつ共通AXI境界へ接続するか。RISC-V優先度整理まではブロッカーにしない。
- Gowin toolと`iverilog`の互換性を踏まえ、共通portをSystemVerilog `interface`とflat bundleのどちらにするか。
- Mega非ProのB/C device版を別board targetに分ける必要があるか。
