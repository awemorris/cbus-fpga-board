# ws002p002: 共通IPトップと安全なboard境界

最終更新: 2026-09-01

Status: completed

Parent: [WS002](../ws.md)

Queue: `Q20260901-009`

## Scope

Primer 20K SO-DIMMとMega 138K非Pro BTBで差し替え可能なboard-independent `cbus_ip_top`、board top、Cバスpad/OE安全境界、確認済みpackage pin constraintを実装する。

今回含めるもの:

- SystemVerilog `interface`を使わないflat-port共通境界。
- 既存`cbus_target_guarded_axil_subsystem`を収容する`cbus_ip_top`。
- 69 endpointを同じ論理portへ接続するPrimer/Mega board top。
- `power_good && config_done && clock_locked && reset_released && external_safety_latch && bus_permit`で全pad OEと外付けLVC OEを即時禁止できる`cbus_pad_adapter`。
- 受動target buildで未実装のmemory/DMA/bus-master/IRQ出力を安全側へ固定する境界。
- Sipeed公式回路図から照合できたpackage pinとLVCMOS33だけを記述するCST。
- iverilog自己検査とCSV/CST/RTL構造validator。

今回含めないもの:

- Gowin PLL、DDR controller、configuration status等の実device primitive。
- 外付けLVC、OE pull-up、clock monitor、安全latchの回路図・PCB。
- Gowin IDEによる合成、place-and-route、bitstream生成。
- memory cycle、DMA、bus master、IRQ機能の有効化。
- 実機への接続、通電、波形・電流測定。

## Purpose

board固有pinとvendor実装がCバス/AXI機能へ漏れない境界をコードで固定し、二つのTang moduleが同じIPを利用できることと、許可条件が一つでも崩れたときに出力要求がHigh-Z側へ落ちることを論理検証する。

## Goal

同じ`cbus_ip_top`を変更せずPrimer/Mega双方のtopがelaborateし、69 endpointのpackage mappingが機械検査でき、安全gateが全不許可状態でpad OEとactive-low LVC OEを禁止する。

## Preconditions and evidence

- 共通69 endpointとconnector mappingは`ws001p002-resume`で完了済み。
- Primer packageはSipeed `Tang_Primer_20K_SOM-3961_Schematic.pdf`のFPGA pin/connector表を正本とする。
- Mega packageはSipeed `tang_mega_138k_30353_Schematics.pdf` sheet 6のnet名、および公式example CSTを正本とする。
- Primer deviceは`GW2A-LV18PG256C8/I7`、Mega非Proは`GW5AST-LV138PG484AC1/I0`を対象とする。
- `iverilog` 12.0を利用できる。Gowin IDEは今回の検証環境に含まれない。

## Implementation policy

1. 共通IPはboard名、package pin、PLL/DDR primitiveを参照しない。
2. `cbus_pad_adapter`の最終OEは安全条件との組合せ論理にし、clocked stateに依存せず即時禁止できるようにする。
3. active-low LVC OEは不許可時に`1`、FPGA pad OEは不許可時に`0`とする。DIRは不許可時にhost-to-FPGA側の安全定数へ戻す。
4. configuration中の安全性はRTLだけで主張しない。CSTのpull指定に依存せず、carrierの各LVC OEに外付けpull-upが必要であることを契約へ明記する。
5. clock停止時の安全性は実PLL lock/外付けclock monitorの実装後まで未証明とする。このPhaseでは`clock_locked`を安全契約入力として検証する。
6. 未実装機能のphysical endpointはportから削除せず、出力とOE requestを非assertへ固定する。
7. CSTは確認できたlocationと`LVCMOS33 PULL_MODE=NONE`だけを記載し、drive/slewを推測しない。

## Work procedure

1. Primerのconnector netからpackage pinへの対応を一次資料から抽出し、Megaのnet内package pinとともにconstraint manifestへ固定する。
2. `cbus_pad_adapter`とplatform status/drive contractを実装する。
3. 既存target/CDC/AXI guardを収容するflat-port `cbus_ip_top`を実装する。
4. Primer/Mega board topを実装し、同じ共通IP portへ69 endpointを接続する。
5. 二つのCSTとmapping validatorを追加する。
6. 安全条件の全組合せ、read/write/非選択、reset中断、二つのtopの同値動作をiverilogで検証する。
7. 既存WS001/WS002 validatorとWS003の635 checksを回帰する。
8. M/W/P/Qを実績へ同期する。

## Verification and completion conditions

- `cbus_pad_adapter`で六つの許可条件のいずれかが0なら、全pad OE=0、全LVC OE_n=1になる。
- reset/config/clock/platform/bus不許可はcycle途中でも同じsimulation timestepで出力を禁止する。
- Primer/Mega topが同じ`cbus_ip_top`をinstantiateし、iverilog `-Wall -Wimplicit`でwarningなくelaborateする。
- 両topで通常I/O read/writeと非選択cycleが同じ結果になる。
- 69 endpointとCST locationが一対一で、connector mapping・bank・LVCMOS33条件と一致する。
- `rtl/ip/`以下にPrimer/Mega/Gowin/package pin/DDR固有名がない。
- 既存635 checksとWS001/WS002 validatorが回帰PASSする。
- Gowin合成と実回路で未検証の条件が文書に残り、RTL simulationだけを実機High-Z証明として扱っていない。

## Residual work boundary

Gowin primitive wrapper、停止clock時のlock解除、configuration pin state、外付けOE pull-up、power sequence、DIR/OE break-before-make、PCB配線は、回路図とtoolchainを入力に`ws002p003`以降で扱う。これらが確定するまでCバス実機へ接続しない。

## Execution result

2026-09-01 Queue `Q20260901-009`で完了した。

- `rtl/ip/cbus_ip_top.sv`へ既存target/CDC/AXI guardを収容し、24-bit address、16-bit data、command、response、DMA、286+ bus-master予約、九つのLVC要求をflat portで固定した。
- memory/DMA/bus-master/IRQ未実装buildは全drive requestを非assertへ固定した。local AXI target未実装時は`axil_error_target`がDECERRで有限終了する。
- `cbus_pad_adapter`は六つのpermit条件を組合せ論理でgateし、不許可時にFPGA pad OE=0、六つのactive-low LVC OE=1、三つのDIR=host-to-card receiver側へ戻す。
- Primer/Mega wrapperは同一`cbus_board_shell`をinstantiateする。Gowin status wrapper未実装時の既定parameterはdrive-disabledであり、raw-clock動作はsimulation専用parameterを明示した場合だけ有効になる。
- Sipeed公式回路図からPrimer/Megaの69 package locationを固定し、各boardのCSTにonboard clockを加えた70 locationを生成した。drive/slewは推測せず、LVCMOS33と`PULL_MODE=NONE`だけを記述した。

再現コマンド:

```sh
plan/ws002-fpga-platform/tests/run_iverilog.sh
plan/ws003-target-bridge/tests/run_iverilog.sh
python3 plan/ws001-cbus-contract/tests/validate_signal_matrix.py
python3 plan/ws001-cbus-contract/tests/validate_platform_maps.py
python3 plan/ws002-fpga-platform/tests/validate_pinouts.py
```

結果:

```text
tb_cbus_pad_adapter: PASS: 3340 checks
tb_portable_board_tops: PASS: 15 checks
new WS002 total: 3355 checks
existing WS003 regression: PASS: 635 checks
combined HDL total: 3990 checks
Primer/Mega constraint and portable-top validators: PASS
WS001 signal/platform and WS002 pinout validators: PASS
```

Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でcompile warningなし。外付けpull-up、停止clock、configuration中のpin state、Gowin合成、電気適合は未検証であり、実機High-Zの証明とはしていない。

Follow-up: Queue `Q20260901-010`で暫定`axil_error_target`をSystem CSRへ置き換えた。上記は`ws002p002`完了時点の実行記録である。
