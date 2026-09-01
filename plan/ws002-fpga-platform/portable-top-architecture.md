# Primer 20K primary / board-independent IPトップ境界

初回決定: 2026-08-31

hardware target方針更新: 2026-09-01

状態: implemented logical boundary in `ws002p002`; 2026-09-01にPrimer-only hardware方針へ更新; production hardware wrapper未実装

## 1. 決定

Tang Primer 20Kを、回路図、PCB、製造、合成、実機検証、頒布の唯一のprimary board targetとする。Tang Mega 138K非Proは、共通IP/ABIがPrimerに密結合しないことを確かめるreference targetに限定する。Cバス機能、AXI subsystem、CSR、mailbox、将来のDMA/RISC-V/user IPは、ボード名やFPGA pinを持たない共通`cbus_ip_top`の下へ置く。

```text
tang_primer20k_top (primary)       tang_mega138k_top (reference)
  product pins / CST                existing pins / CST
  product clock-reset-DDR wrapper   elaboration + ABI regression
  product LVC/OE/PCB                no project carrier/PCB
                  \                  /
                   +-- cbus_ip_top --+
                       |
                       +-- cbus target / AXI bridge
                       +-- CSR / mailbox / DMA
                       +-- user IP boundary
                       +-- future RISC-V subsystem
```

プロジェクトのproduction buildはPrimer top/constraint/platform wrapperだけを使用する。Mega top/constraintはreference CI/build用に保持する。`cbus_ip_top`以下のRTL source、register map、testbenchは同一にし、共通IP内で`PRIMER`/`MEGA`の`ifdef`分岐を作らない。

## 2. Board-specific topの責務

- FPGA package pin、I/O standard、drive、slew、専用clock pinをconstraintへ割り当てる。
- Primer SO-DIMMの物理pinを共通Cバス論理portへ対応付ける。Mega BTB mappingはreference topの回帰資産としてのみ保持する。
- Gowin PLL、clock buffer、DDR controller、IOBUFなどdevice/board固有primitiveをwrapper内へ閉じ込める。
- 外付けLVCのDIR/OE pin groupを物理配線へ対応付ける。
- `cbus_ip_top`の`oe_req`を、そのまま外部へ出さず、`platform_ready && reset_released && clock_locked && bus_permit`でgateする。
- FPGA configuration中はRTLに依存せず、LVC OE pull-up等の外付け回路でHigh-Zを保証する。
- ボード固有LED、button、UART、configuration pinは、共通diagnostic interfaceへ必要なものだけ接続する。
- Primer DDR wrapperは共通IPへAXI memory target interfaceを提示する。Mega側はIP参照に必要な範囲で同じ論理interfaceを維持できるが、実機合格をproduction条件にしない。

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

`ws002p002`ではIcarus/Gowin間の可搬性と構造検査の単純さを優先し、SystemVerilog `interface`ではなくflat port bundleを採用した。

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
    tang_mega138k_top.sv       # IP portability reference only
  platform/
    primer20k/...
    mega138k/...               # reference assets; no project PCB
  vendor/gowin/...
constraints/
  primer20k/*.cst
  mega138k/*.cst
sim/
  cbus_ip_top/...
```

`ws002p002`で`rtl/ip/cbus_ip_top.sv`、`rtl/platform/cbus_pad_adapter.sv`、共通board shell、二つのboard top、二つのCSTを配置した。Gowin primitive wrapperとproduction timing constraintは未配置である。

## 6. 受入条件

- 同一の`cbus_ip_top`を変更せず、Primer production topとMega reference topがelaborateできる。
- board名、package pin、DDR part名、PLL primitiveが`rtl/ip/`以下に現れない。
- 共通IPの自己検査testを一度実行すれば、両topで共有できる機能の論理検証になる。
- Primer topはreset/config/clock不成立時のLVC OEがHigh-Z側になるassertion、構造検査、将来の合成/実機検査を必須とする。Mega reference topは論理assertion/構造検査までを維持する。
- capability差は黙ったport削除ではなく、定数、CSR、build assertionへ表れる。
- register map、firmware ABI、user IP AXI境界はboard差し替えで変わらない。

## 7. 保留事項

- `ws003p004`で追加したlogical `cbus_sale_i`は現行board shellで0へ固定している。A39のS2/SALE世代多重、LVC方向、selector、Primer pin、CSTをIP-complete gate後のphysical planningで決定すること。
- 初回基板でbus-master用LVC/pinを実装済み、DNP、未配線のどれにするか。
- Primer DDR controllerをいつ共通AXI境界へ接続するか。RISC-V優先度整理まではブロッカーにしない。
- Gowin IDEでflat port/CSTを合成し、device版とtiming closureを確認すること。
- Mega reference資産の保守コストが過大になった場合、どの論理回帰水準までをIP supportとするか。物理carrierの追加は新たなユーザ判断なしに行わない。
