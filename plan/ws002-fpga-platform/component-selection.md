# ws002p001 FPGA・LVC・給電構成比較結果

調査日: 2026-08-31

hardware target方針更新: 2026-09-01

## 1. 結論

最初のCバス・キャリアには **Tang Primer 20K SO-DIMM** を推奨する。保守的に数えても、Cバスへ割り当て可能な3.3 V双方向GPIOは86本ある。後続mappingで独立response OEとDMA WORD OEを反映し、受動target、選択DMA、286以降bus-masterを同時予約する69 endpointへ訂正した後も17本残る。204-pin SO-DIMMソケットはMegaの0.4 mm BTBより試作しやすく、モジュールも交換できる。

ただし、Primerの公式電源要求は5 V±10%、0.5 Aである。NEC資料で+5 V 0.5 A/slotとされる初期機ではモジュールだけで上限へ達し、後期の0.8 A/slotでもLVC、保護回路、突入を入れる前の余裕は0.3 Aしかない。したがって、PC-9800シリーズ全般を目標にするキャリアには次を入れる。

- Cバス+5 Vを通常選択とする。
- 基板側にキー付き`AUX_5V` 2極入力を設ける。
- Cバス+5 Vと`AUX_5V`を直接並列にせず、試作では物理的に排他的なジャンパ/スイッチ、将来PCBでは逆流阻止付きパワーマルチプレクサを使う。
- FDD側は機種ごとのコネクタ差を吸収する交換式ハーネスとし、基板へ「PC-98 FDDコネクタ」を直接決め打ちしない。
- 各入力にヒューズまたはPTC、逆極性/逆流保護、入力バルク容量、電源選択表示を設け、通電中の切替・挿抜を禁止する。

Tang Mega 138K非Pro SOMは144本の保守的GPIOを持つことを調査済みである。2026-09-01の方針更新により、Megaは共通IP/ABIの移植性を確かめるreference targetとして残すが、工場実装する専用PCB候補から外した。3個の0.4 mm BTB、Mega電源、筐体、PCBA条件を本プロジェクトの製品設計として追い込まない。Primerの204-pin SO-DIMM socketはfine-pitch SMTなので、socket自体は実装済みadapterまたは工場実装を使う。

Tang Nano 20K直結は、独立IORDY/IRQ OEを含む8-bit I/O最小構成だけで35本となり、34 GPIOを1本超えるため不採用とする。全オンボード負荷を自由に切り離せる保証もない。外部CPLDを足す案は成立し得るが、CPLDが実質的なCバス・コントローラになり、ローカル転送プロトコル、二重コンフィグ、タイミング/CDCの新規設計が必要になるためPrimerより単純ではない。

## 2. I/O成立性

機械可読な比較結果は [io-platform-comparison.csv](io-platform-comparison.csv)、端子全数は [tang-primer-20k-sodimm.csv](tang-primer-20k-sodimm.csv) と [tang-mega-138k-btb.csv](tang-mega-138k-btb.csv) に記録した。

| 候補 | 保守的なCバス用GPIO | 69 endpoint同時予約後の余裕 | 判定 |
| --- | ---: | ---: | --- |
| Tang Nano 20K直結 | 34 | -35 | 不採用。35本の最小構成にも1本不足。 |
| Tang Nano 20K + 外部CPLD | モジュール直結値では比較不能 | CPLD品種次第 | 条件付き。別アーキテクチャになる。 |
| Tang Primer 20K SO-DIMM | 86 | +17 | 初回推奨。 |
| Tang Mega 138K BTB | 144 | +75 | IP移植性referenceのみ。対応PCBは作らない。 |

### 2.1 Primer 20Kの103/117 I/O差

公式回路図3961のSO-DIMM全204端子を抽出すると、次の内訳になった。

| 分類 | 本数 | Cバス割当 |
| --- | ---: | --- |
| 通常3.3 V双方向GPIO | 86 | 可 |
| 1.5 V入力専用 | 8 | 不可 |
| JTAG | 4 | 予約 |
| Reset | 1 | 予約 |
| RECFG/READY/DONE/FASTRD | 4 | 予約 |
| 専用PLL入力 | 1 | 予約 |
| 電源/GND/NC | 100 | 不可 |

データシートの`103 User IOs`は、86+8+4+1+4=103として回路図と整合する。これとは別に専用PLL入力が1本ある。Wikiの`117 Available IO`は、公式回路図のSO-DIMM端子集合から再現できなかったため、設計値に使わない。

86本のバンク内訳はBank 0=22、1=20、2=10、3=18、7=16である。モジュール回路図の現行電源構成を前提に3.3 Vとして扱うが、キャリアから`F_VCCO`へ別電圧を注入する改造は初版で行わない。8本の1.5 V入力専用、JTAG、Reset、Configuration、PLL入力はCバスへ割り当てない。

Cバス側の基準クロックはNEC資料で最大約9.8304 MHz級であり、今回の部品選択では各FPGAの一般I/Oがこの周波数を扱えるかを一次screening条件とした。Primer/Megaとも速度を理由とする不成立はないが、Cバス非同期入力のsampling、input delay、LVCを含むsetup/holdは未確定であり、`ws001p003`の世代別タイミングと実際のGowin speed gradeで制約・STAを通すまで「全機種のタイミング成立」とはしない。Nano+CPLD案はlocal protocolの遅延が未定なので速度判定も条件付きである。

### 2.2 Mega 138KのBTB

以下はIP reference topの端子根拠を保存するための比較記録である。2026-09-01以後の調達、回路図、PCB、実装計画ではない。

非Pro SOMのコネクタは、`C2399`/`C2400`が`DF40C-100DP-0.4V(51)`、`BTB9900`が`DF40C-80DP-0.4V(51)`で、計280接点である。内訳は次のとおり。

| 分類 | 本数 | Cバス割当 |
| --- | ---: | --- |
| Bank 2/3/4の確認済み3.3 V GPIO | 144 | 可 |
| Bank 5 | 35 | 電圧・用途確定まで予約 |
| SerDes | 20 | 不可 |
| ADC | 4 | 不可 |
| JTAG/Configuration | 11 | 予約 |
| 電源/GND/NC | 66 | 不可 |

最新配布名30354のPDFは内部Titleが30353で、コネクタページを旧30353と目視比較した範囲ではコネクタ型番・端子配置に差は見つからなかった。抽出CSVは文字抽出可能だった30353をreference正本とする。Mega reference topを将来改定する場合だけ、対象device版の最新回路図とGowin IDE Device Versionを再照合する。

比較時はMega SOM側のplugに対し、同じ極数のDF40 DS receptacleを3個用いる工場SMT/AOI前提のcarrierを想定した。これは不採用案の実装性根拠として保存し、コネクタsuffix、stack height、筐体クリアランスの確定作業は行わない。

## 3. 5 V-CMOSフロントエンド

第一候補を`SN74LVC16245A`、オープンコレクタ線を`SN74LVC07A`とする。割当案は [lvc-allocation.csv](lvc-allocation.csv) に記録した。

`SN74LVC16245A`は16 bitを独立した2個の8-bit groupとして持ち、それぞれにDIRとactive-low OEがある。3.3 V給電で5.5 V tolerant input、Ioff、最大4 ns級の伝搬遅延、±24 mAの出力能力を持つ。NEC資料の後期機向け外部ロジック条件で最も重い12 mA sink / -1.2 mA sourceに余裕がある。OEには電源投入中にHighを保証する外付けpull-upを置き、FPGA未設定、reset、clock未確立、バス非所有のいずれでもLVC出力をHigh-Zにする。

この比較で確認できたのはLVC側の5 V入力許容とNEC側の外部ロジック駆動電流である。PC-9800全世代の入力threshold、pull-up、leakageを一枚の資料で確定できてはいないため、3.3 V High出力のシリーズ全般適合は`U-ELEC-001`のまま代表機実測へ残す。部品採用前に信号別VOH/VOLと対象世代のVIH/VILをworst-caseで再照合する。

`74LVC162245A`は約30 Ωの出力直列抵抗を内蔵し配線反射を抑えやすいが、Nexperia品の出力保証は±12 mAで、NECの最悪sink条件と同値になり余裕がない。さらに一部package/メーカー品はobsoleteまたはlast-time-buy表示がある。このため初回は駆動余裕のある16245Aを実装し、必要な直列抵抗をキャリア側で個別に調整できるようにする。162245Aは測定後のBOM代替候補に留める。

IR9、IOCHK、DRQ、EXHRQ、NOWAIT、MACSなどオープンコレクタ指定線はpush-pull transceiverでLow/Highを駆動しない。5.5 V tolerant input、Ioff、open-drain出力を持つ`SN74LVC07A`でLowだけをsinkする。全世代多重線を同時実装して6chを超える場合は2 package目をDNP footprintとして用意する。

| 構成 | 16245A | LVC07A | 備考 |
| --- | ---: | ---: | --- |
| 20/24-bit受動ターゲット | 4/5 | 1 | 初回は24-bit配線を推奨。論理で20-bit縮退。 |
| 24-bit + 従来DMA | 6 | 1 | DMAごとに独立OEを確保。 |
| 24-bit + bus master | 6 | 1 + DNP 1 | アドレス/command/arbitrationを双方向化。初期実装では無効。 |

この部品数は回路図用の安全側stuffing estimateであり、信号を空きoctetへ詰めて部品数だけを減らしていない。独立DIR/OE、安全permit、配線負荷を優先し、`ws002p002`の回路契約で最終化する。

## 4. 給電

詳細値は [power-options.csv](power-options.csv) に記録した。

NEC 1993 Hardware Technical Databook p.302は、PC-9801 E/F/M/U/VF/VM/UVの列挙された初期機種を+5 V 0.5 A/slot、その他を+5 V 0.8 A/slotとする。したがって「Cバス給電でぎりぎり成立」は後期0.8 A機についてだけの暫定評価であり、PC-9800シリーズ全般の保証にはできない。

Primerは0.5 A要求なので、初期0.5 A slotのheadroomは0 mA、後期0.8 A slotでも300 mAである。LVCの静的消費は小さいが、FPGA設計、DDR、I/O toggle、LED、LVC負荷、起動突入によって実電流が変わる。専用測定器がない現状では最大値を実証できないため、次の判定を採用する。

- Primer + 後期0.8 A slot: Cバス単独を既定として配線可能。ただし電流測定前は暫定。
- Primer + 初期0.5 A slot: `AUX_5V`を使用。
- Mega: 非Pro SOMの公式最大電流を確認できなかった。この未確認はreference史料に残すが、Mega試作/電源回路は作成しない。Dockの12 V入力値やMega Proの5 V 110-1500 mA値を非Pro SOMへ転用しない。
- 外部5 V: ベンチ試験とFDDハーネスが使えない機種の代替。安定化5 Vを使い、GNDを先に接続し、hot-plugしない。

PC-98のFDD電源は機種・ドライブでコネクタや信号束が異なり、V13の一次資料でpinoutを確定できなかった。一般的な3.5 inch/5.25 inch FDDコネクタの見た目や配色を根拠に極性を固定しない。基板側をキー付き2極`AUX_5V`へ統一し、対象機ごとに導通確認済みの短い分岐ハーネスを作る方式なら、キャリアをシリーズ共通に保てる。

初回ユニバーサル基板は、電源選択を物理的に一意にできる3-position headerまたは2回路スイッチにし、両入力を同時接続できない構造とする。専用PCBではload switch/ideal-diode controllerを比較し、逆流、soft-start、undervoltage、過電流を扱う。

## 5. 実装性と概算BOM

数量1、2026-08-31取得、送料・税・PCB・Cバスedge/ブラケット・実装費を除く部品概算は [bom-estimate.csv](bom-estimate.csv) のとおりである。

- Primer受動ターゲット: 約USD 43-97。
- Primerをbus-master-readyにする追加論理: 約USD 2-4程度、ただしコネクタ/配線面積も増える。
- Mega受動ターゲット: 比較時の参考値は約USD 91-199。不採用hardware案の履歴であり、再見積りしない。

価格は2026-08-31の設計比較用であり注文保証ではない。Primerの下限は価格アーカイブ、上限はmarketplaceの単品在庫、MegaはSOM/Dock variantが混在するmarketplace帯を用いた。Mega関連値は不採用hardware案の履歴としてのみ保存する。

Primerの204-pin SO-DIMM socketはfine-pitch SMTなので、生socketをユニバーサル基板へ直接手はんだする案にはしない。最初はsocket実装済みbreakout/adapter、またはsocketだけ実装サービスへ依頼した小型adapter PCBから2.54 mm headerへ引き出し、SSOP LVCと電源部をユニバーサル基板で組める。専用PrimerキャリアではsocketとLVCをまとめて工場実装する。Mega carrier実装は行わない。

## 6. 推奨する判断と次の境界

`ws002p001`の推奨は次の組合せである。

1. FPGA: Tang Primer 20K SO-DIMM。
2. 初回機能: 24-bitアドレス/16-bitデータを物理配線した受動target。論理は20-bit/8-bitへ縮退可能にする。
3. Level shift: 5×`SN74LVC16245A` + 1×`SN74LVC07A`。DMA/bus master用は別stuffing optionとし、初回はdrive permitを恒久無効にする。
4. 電源: Cバス+5 V既定 + キー付き`AUX_5V`。排他選択、PTC/ヒューズ、逆流防止、bulk/decouplingを持つ。
5. Mega: 同じ論理pin contract/ABIを使うIP reference targetとして保持する。Mega用Cバスキャリアは作成しない。

2026-08-31のQueue終了後、ユーザはPrimer 20KとMega 138Kが同一のboard-independent IP topを使う方針を決定した。2026-09-01に対応水準を更新し、作成する試作/専用ボードはPrimer 20Kだけに絞り、Mega 138KはIP/ABI referenceとしてのみサポートする。残るユーザ判断は「初回Primer PCB/配線でbus-master向けLVCと配線を未実装、DNP、実装済みのどれにするか」である。FDDハーネスのPC側コネクタは、V13実機のコネクタ写真、電圧/導通確認、完全型番が得られてから確定する。これらは将来ユーザが承認するP/Qで扱う。

## 7. 再現方法

```sh
python3 plan/ws002-fpga-platform/tests/validate_pinouts.py
```

使い捨ての公式PDF/XHTMLを再取得した場合だけ、次で端子CSVを再生成できる。

```sh
python3 plan/ws002-fpga-platform/tests/extract_connector_pinouts.py \
  --primer-xhtml plan/ws002-fpga-platform/temp/primer20k-som-3961.html \
  --mega-xhtml plan/ws002-fpga-platform/temp/mega138k-btb-page.html \
  --output-dir plan/ws002-fpga-platform
```

## 8. 主要出典

- Sipeed, Tang Primer 20K公式Wiki: <https://en.wiki.sipeed.com/hardware/en/tang/tang-primer-20k/primer-20k.html>
- Sipeed, Tang Primer 20K Datasheet V1.0: <https://dl.sipeed.com/fileList/TANG/Primer_20K/01_Specification/Sipeed%20Tang%20Primer%2020K%20Datasheet%20V1.0.pdf>
- Sipeed, Primer/Mega公式回路図配布: <https://dl.sipeed.com/>（3961、Mega 30353/30354を取得）
- Sipeed, Tang Mega 138K非Pro公式Wiki: <https://en.wiki.sipeed.com/hardware/en/tang/tang-mega-138k/mega-138k>
- Texas Instruments, SN74LVC16245A: <https://www.ti.com/product/SN74LVC16245A>
- Texas Instruments, SN74LVC07A: <https://www.ti.com/product/SN74LVC07A>
- Nexperia, 74LVC/LVCH162245A: <https://www.nexperia.com/products/analog-logic-ics/logic/buffers-inverters-transceivers/transceivers/serie/74lvc162245a-74lvch162245a>
- Hirose, DF40C-100DP-0.4V(51): <https://www.hirose.com/product/p/CL0684-4032-1-51?lang=en>
- Hirose, DF40C-80DP-0.4V(51): <https://www.hirose.com/en/product/p/CL0684-4001-8-51>
- NEC, PC-9800 Technical Databook Hardware 1993: [WS001 evidence register](../ws001-cbus-contract/evidence.md)
- DigiKey, SN74LVC16245A qty-1 price: <https://www.digikey.com/en/products/detail/texas-instruments/SN74LVC16245ADLR/377449>
- Mouser, DF40HC(3.0)-100DS-0.4V(51) qty-1 price: <https://www.mouser.com/en/ProductDetail/Hirose-Connector/DF40HC3.0-100DS-0.4V51>

一次資料で確定できなかった事項は、Mega非Proの最大消費電流、V13 FDD電源pinout、各機種のslot電源上限/入力threshold、LVC込み実消費、最適な直列抵抗、Megaの最終stack heightである。いずれも推測値を部品確定へ昇格させていない。
