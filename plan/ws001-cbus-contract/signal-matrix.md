# WS001 Cバス信号マトリクス

最終更新: 2026-08-31

対象Phase: `ws001p002`

## 1. 結論

- NEC資料のデスクトップ用CバスはA1-A50/B1-B50の100端子である。`signal-matrix.csv`に全100端子を登録した。
- AB00-AB23は、8086/µPD70116タイプと80286/386/486/Pentiumタイプの両方のピン表に存在する。したがって、物理的な24本の存在を「286以降だけ」とは扱わない。
- 一方、8086用の古いROMボードはAB20-AB23をデコードしない。80286以降機には、上位4 bitが0のときだけAB19を旧ボードへ渡す互換切替がある。設計能力は`20-bit互換デコード`と`24-bitフルデコード`へ分ける。
- CPU世代でA37-A40、B40、B42、B46-B48の意味、方向、出力形式が変わる。固定配線だけで両世代を同じ論理信号として扱ってはならない。
- Tang Nano 20KのJ5/J6には34本のFPGA I/Oが出ているが、全端子がオンボード周辺回路と共有される。独立したIORDY/IRQ OEまで含む8-bit I/O最小構成は35本であり、最小構成から不足する。
- Primer/Mega共通IP用に、24-bit/16-bit受動target、選択IRQ、選択DMA一経路、286以降型bus-master、独立安全OEを同時予約した69 endpointを作成した。Primerは17本、Megaは75本の保守的3.3 V GPIOを残して成立する。

Tang Nano 20Kの不足は、Primer 20K/Mega 138Kを差し替え可能なboard targetとして採用することで解消した。共通endpointと両module connector mappingは[platform-mapping.md](platform-mapping.md)を参照する。

## 2. 正本と生成物

| ファイル | 役割 |
| --- | --- |
| `signal-matrix.csv` | 全100端子、世代別信号、方向、極性、出力形式、RTL名、変換器グループの正本。 |
| `translator-groups.csv` | 同じ方向・OE・出力形式で扱える物理グループの契約。 |
| `tang-nano-20k-headers.csv` | Tang Nano 20KのJ5/J6全40端子と34 GPIO、バンク、共有負荷。 |
| `io-budget.csv` | 機能プロファイル別のFPGA I/O予算。 |
| `platform-endpoints.csv` | Primer/Megaで共通の69 endpoint正本。 |
| `primer20k-platform-map.csv` | 共通endpointからPrimer SO-DIMM connector/netへの対応。 |
| `mega138k-platform-map.csv` | 共通endpointからMega BTB connector/netへの対応。 |
| `tests/validate_signal_matrix.py` | 端子数、一意性、参照整合、I/O予算を検査する。 |
| `tests/build_platform_maps.py` | 公式端子CSVから二つのmappingを再生成する。 |
| `tests/validate_platform_maps.py` | 69 endpoint、3.3 V GPIO限定、pin/bank/残余数を検査する。 |

## 3. 方向の読み方

NECピン表の`I/O`は本体側から見た方向である。本台帳では次の正規名へ変換した。

| 台帳値 | 意味 |
| --- | --- |
| `host_to_card` | PC本体が駆動し、カードが受信する。 |
| `card_to_host` | カードが駆動またはLowへ吸い込み、本体が受信する。 |
| `bidir` | バス所有権またはサイクル方向により変わる。 |
| `power` | 電源またはGND。 |
| `reserved` | NEC表で機能・方向の説明がない。接続しない。 |

受動ターゲットではABとコマンドを入力として使うが、将来のバスマスタ構成では同じ物理線をカード側から駆動する。このため論理ポートは`_i/_o/_oe`へ分離した。

## 4. 世代差

| 物理端子 | 8086/µPD70116タイプ | 80286以降タイプ | 実装条件 |
| --- | --- | --- | --- |
| A37 | S0 | INTA | 専用世代モードが必要。 |
| A38 | S1、トライステート | NOWAIT、オープンコレクタ | 同じ出力回路へまとめない。 |
| A39 | S2、カード→本体 | SALE、双方向 | 極性と方向が変わる。 |
| A40 | LOCK、トライステート | MACS、オープンコレクタ | 同じ出力回路へまとめない。 |
| A42 | CPUENB、本体→カード | CPUENB、双方向 | 世代モードでOEを禁止する。 |
| B40 | CPKILL | EXHRQ1 | PC-98XAではBANKとなるスロットもある。 |
| B42 | RQGT、双方向 | EXHLA1、本体→カード | 世代モードで方向を固定する。 |
| B46 | HLDA | EXHLA2 | 本体→カード。意味だけが変わる。 |
| B47 | HRQ、トライステート | EXHRQ2、オープンコレクタ | 同じ出力回路へまとめない。 |
| B48 | DMAHLD、カード→本体、Low | SBUSRQ、本体→カード、High | 方向と極性が反転する。 |

B28、B35-B38は機種とスロットによりIRQ/DMAチャネルが変わる。汎用基板で信号名をシルクへ固定せず、物理端子名と論理機能を分ける。

## 5. 変換器グループ

`translator-groups.csv`は部品番号ではなく、同じ方向制御と安全条件を共有できる論理グループである。

- `addr_lo`、`addr_hi`: 受動時は入力、バスマスタ時だけ出力可能な双方向経路。
- `data`: DB00-DB15。サイクルごとのDIRとOEが必要。
- `cmd_bidir`: IOR/IOW/MRC/MWC/MWE/BHE。受動時は入力、バスマスタ時だけ出力。
- `host_ctl_in`、`dma_in`、`arb_in`: Cバスを駆動しない入力専用経路。
- `target_resp_ts`、`irq_ts`、`dma_out_ts`: NEC指定のトライステート出力。
- `target_resp_oc`、`irq_oc`、`dma_out_oc`: Lowへ吸い込むオープンコレクタ相当出力。
- `gen_mux_*`: CPU世代で方向または電気形式が変わるため、他信号とOEを共有しない。

74LVC16245A/162245A等の具体部品、抵抗値、入力閾値、出力電流適合はWS002で検証する。オープンコレクタ指定線を通常のプッシュプル出力へ置き換えてはならない。

## 6. Tang Nano 20K I/O予算

Sipeed公式回路図3850、3920、3921、3923を比較した。J5/J6は合計40端子で、電源/GND 6本を除くFPGA I/Oは34本である。露出バンクは0、1、3、4、5、6で、回路図上は3.3 V給電される。

| プロファイル | 必要I/O | 34本との差 | 判定 |
| --- | ---: | ---: | --- |
| 8-bit同期I/Oターゲット最小 | 35 | -1 | 不成立。 |
| 16-bit同期I/Oターゲット最小 | 44 | -10 | 不成立。 |
| 20-bit・8-bitメモリターゲット最小 | 40 | -6 | 不成立。 |
| 20-bit・16-bitフルターゲット | 51 | -17 | 不成立。 |
| 24-bit・16-bitフルターゲット | 55 | -21 | 不成立。 |
| 従来DMA追加 | 60 | -26 | 不成立。 |
| 286以降バスマスタ追加 | 64 | -30 | 不成立。 |
| DMA・286以降バスマスタ同時予約 | 69 | -35 | 不成立。Primer/Mega mappingの基準。 |

35本の最小構成はAB00-AB15、DB00-DB07、IOR、IOW、RESET、POWER、SCLK、IORDY、IRQ 1本、データDIR/OE、独立IORDY/IRQ OEを数える。前版の33本は最後の二つを欠いていたため訂正した。メモリ、16-bitデータ、BHE、DMA、バスマスタ、デバッグ信号、版差の予備を含まない。

全34 GPIOにはLCD、LED、SD、音声、HDMIまたはオンボードデバッガ等の負荷がある。未使用周辺機能を論理的に無効化しても基板配線と実装負荷は残るため、34本を無条件な自由GPIOとはみなさない。

## 7. High-Z安全真理値

外付け回路は次の`drive_permit`を満たさない限り、Cバス向け全出力をHigh-Zまたは非吸い込み状態にする。

```text
drive_permit = power_good
             & fpga_config_done
             & clock_stable
             & reset_released
             & external_safety_latch
```

`fpga_config_done`だけに依存してはならない。コンフィグ中にFPGA端子が不定でも、外付けプルとゲートでOEを禁止する。

| 状態 | 入力受信器 | DB/AB/command出力 | IRQ/IORDY/DMA出力 | 備考 |
| --- | --- | --- | --- | --- |
| 無給電または電源不安定 | 任意 | 禁止 | 禁止 | Cバスへの逆給電も禁止。 |
| FPGAコンフィグ中/失敗 | 任意 | 禁止 | 禁止 | 外付けOE既定値で保証。 |
| クロック未確立 | 有効可 | 禁止 | 禁止 | 非同期入力観測だけ可。 |
| RESET有効 | 有効可 | 禁止 | 禁止 | RTL状態に依存させない。 |
| 設定済み・受動アイドル | 有効 | 禁止 | 禁止 | DBもHigh-Z。 |
| 対象write | 有効 | 禁止 | 必要時IORDYのみ | DBは本体→FPGA。 |
| 対象read | 有効 | 選択中DBのみ許可 | 必要時IORDY/IRQ | アドレス一致とストローブの窓内だけ。 |
| バス非所有 | 有効 | 禁止 | ターゲット応答だけ条件付き | アドレス/commandは常にHigh-Z。 |
| バスマスタ許可取得後 | 有効 | 許可されたグループのみ | 調停契約どおり | 世代モードとEXHLAを追加条件にする。 |
| watchdog/fault | 有効可 | 禁止 | 禁止 | 外付け安全ラッチを解除。 |

## 8. 未確認事項と再開条件

| ID | 未確認・判断事項 | 再開条件 |
| --- | --- | --- |
| `U-MATRIX-001` | V1/V2端子の機能がNEC参照表で説明されない。 | 別版一次資料または実機回路資料を得るまで未接続。 |
| `U-MATRIX-002` | 1993年資料外の後期PC-9821と、資料にない初期/特殊機の差。 | 機種別資料または対象実機観測を互換性マトリクスへ追加。 |
| `U-MATRIX-003` | Tang Nano 20K実ボード版と共有負荷の無効化条件。 | シルク版数と実装部品を対応するSipeed回路図へ照合。 |
| `U-MATRIX-004` | 34 GPIO不足への製品方針。 | 解消済み。Primer/Mega board topと共通IP topを採用し、69 endpoint mappingを作成した。 |
| `U-MATRIX-005` | 5 V側トランシーバの入力閾値、出力電流、電源断時挙動。 | WS002で候補データシートとNEC DC表を定量照合。 |

## 9. 検証

実行コマンド:

```text
python3 plan/ws001-cbus-contract/tests/validate_signal_matrix.py
python3 plan/ws001-cbus-contract/tests/validate_platform_maps.py
```

検査対象は100端子の過不足・重複、世代別必須列、変換器グループ参照、Tangヘッダ40端子/34 GPIO、FPGAピン重複、I/O予算の算術整合である。
