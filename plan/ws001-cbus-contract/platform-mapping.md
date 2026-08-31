# Primer 20K / Mega 138K共通endpoint・コネクタmapping

更新日: 2026-08-31

対象: `ws001p002` resume / Queue `Q20260831-004`

## 1. 結論

Primer 20KとMega 138Kのboard topから同じ`cbus_ip_top`をinstantiateできるよう、共通endpointを69本に固定し、両モジュールの保守的な3.3 V GPIOへ同じ順序で割り当てた。

| 区分 | endpoint数 |
| --- | ---: |
| Cバスaddress | 24 |
| Cバスdata | 16 |
| I/O/memory command、reset、power、clock | 9 |
| IORDY + 選択式IRQ | 2 |
| 選択式従来DMA（DACK/DRQ/WORD/DMATC） | 4 |
| 286以降型bus-master予約（B40/B47/B42/B46/B48） | 5 |
| LVC DIR/OE安全制御 | 9 |
| 合計 | 69 |

Primerは86本中69本を使い17本、Megaは144本中69本を使い75本残る。JTAG、reset、configuration、Primerの1.5 V入力専用、MegaのBank 5/SerDes/ADCは使用していない。

正本:

- [platform-endpoints.csv](platform-endpoints.csv): board-independent endpoint集合。
- [primer20k-platform-map.csv](primer20k-platform-map.csv): endpointからPrimer SO-DIMM connector/netへの対応。
- [mega138k-platform-map.csv](mega138k-platform-map.csv): endpointからMega三つのBTB connector/netへの対応。

このQueueではmodule connectorまでを固定した。Gowin package pinとCSTは、Sipeed公式constraint/回路図を再照合する`ws002p002`の実装対象であり、今回のCSVの`module_net`をpackage pinと読み替えてはならない。

## 2. I/O予算の訂正

前Queueまでの33/42/53/57/62本は、IORDYとIRQの独立OE、およびDMA WORDの独立OEを数えていなかった。IORDYは選択cycleだけ、IRQはcycle外でも保持されるのでOEを共有できない。WORDもDMA active windowが別である。

訂正後は次のとおり。

| profile | FPGA I/O | Nano 34との差 |
| --- | ---: | ---: |
| 8-bit I/O target最小 | 35 | -1 |
| 16-bit I/O target最小 | 44 | -10 |
| 20-bit/8-bit memory最小 | 40 | -6 |
| 20-bit full target | 51 | -17 |
| 24-bit full target | 55 | -21 |
| 24-bit + selected DMA | 60 | -26 |
| 24-bit + 286+ bus master | 64 | -30 |
| DMAと286+ bus-masterを同時予約 | 69 | -35 |

これによりNano直結は「余裕1本」ではなく、最小構成でも1本不足すると確定した。Primer/Megaの成立判断は変わらない。

## 3. Bank配置方針

### Primer 20K

| 用途 | Bank | 本数 |
| --- | ---: | ---: |
| AB00-AB21 | 0 | 22 |
| AB22-AB23 | 2 | 2 |
| DB00-DB15 | 7 | 16 |
| command/response/DMA/master physical path | 1 | 20 |
| LVC DIR/OE | 3 | 9 |

未使用の保守的GPIOはBank 1=0、2=8、3=9、0/7=0、合計17本である。addressの2本だけBank 2へ跨るが、外付けLVC octetの配線順とPCB routingを確定するまでは、SO-DIMM端子番号の機械的な並びを優先した仮固定である。

### Mega 138K

| 用途 | Bank | 本数 |
| --- | ---: | ---: |
| AB00-AB23 | 2 | 24 |
| DB00-DB15 | 3 | 16 |
| command/response/DMA/master + LVC DIR/OE | 4 | 29 |

未使用の保守的GPIOはBank 2=26、3=34、4=15、合計75本である。

## 4. 共通IP境界

- Address/data/commandは`*_i`、`*_o`、`*_oe_req`の論理bundleとするが、module connector側では外付けbidirectional transceiverへ接続する1 endpoint/bitである。
- `safe_drive_if`の9本はboard topが生成する最終DIR/OE pinであり、共通IPの要求をreset/clock/platform ready/bus permitでgateする。
- IORDY OE、IRQ OE、WORD OEは相互に共有しない。
- Address/command DIR/OEは286以降型bus-masterを有効にするbuildだけが動かす。受動target buildではhost-to-FPGA/High-Z側へ固定する。
- 共通IP内にPrimer/Mega分岐を入れず、両mapping CSVの`common_port`列を一致させる。

## 5. Selector境界

IRQと従来DMAの機種/slot差を共通IPへ持ち込まないため、次の三つはcarrier-selected endpointとした。

- `cbus_irq_selected`: IR3/5/6/9/10(11)/12/13と、tri-state/open-drain pathの選択。
- `cbus_dack_selected_n`: B35/B36の選択。
- `cbus_drq_selected_n`: B37/B38とopen-drain pathの選択。

jumper、analog switch/mux、複数bufferのDNP selectionのどれを使うかは回路図判断として未確定である。このCSVはFPGA側endpointを一つに固定しただけで、異なるCバス出力同士を直接短絡することを許可しない。

## 6. 世代境界

今回のbus-master予約は、B40/B47をopen-drain EXHRQ1/2、B42/B46をEXHLA1/2、B48をSBUSRQとして使う286以降型profileである。8086型のCPKILL/RQGT/HLDA/HRQ/DMAHLDは同じ物理pinでも方向・出力形式が異なるため、この予約経路を流用して有効化しない。必要になった時点で別のgeneration capabilityと外部出力pathを計画する。

受動targetの24-bit address pin自体は両世代に存在し、20-bit互換は共通IPのdecode policyとして縮退する。

## 7. 再現と検証

```sh
python3 plan/ws001-cbus-contract/tests/build_platform_maps.py
python3 plan/ws001-cbus-contract/tests/validate_signal_matrix.py
python3 plan/ws001-cbus-contract/tests/validate_platform_maps.py
```

検証は69 endpointの順序・一意性、全Cバスpin参照、両boardのconnector pin重複、source CSVとの一致、3.3 V通常GPIO限定、bank集計、残余GPIOを確認する。
