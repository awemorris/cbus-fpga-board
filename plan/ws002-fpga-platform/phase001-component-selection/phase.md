# ws002p001: FPGA・LVC試作構成の選定

最終更新: 2026-08-31

WSID: `ws002`

Phase ID: `p001`

Combined ID: `ws002p001`

Status: completed

Parent: [WS002](../ws.md)

## Objective

ユニバーサル基板試作に使えるTangモジュール、ソケット、LVC、電源、安全部品の候補を、I/O成立性、電気仕様、実装性、原価、供給性で比較し、ユーザが選択できる試作構成案を作る。

## Dependencies and fixed decisions

- `ws001p001`の電圧・方向・タイミング根拠が利用できる。
- `ws001p002`当初予算ではTang Nano 20Kの34 GPIOに対して8-bit I/O最小33本としていたが、後続mappingでIORDY/IRQ独立OEを加え35本へ訂正した。Nanoは最小構成でも不足する。
- Tangファミリ、外付けLVC、FPGAモジュールを交換可能にする方針である。
- 74LVC16245A/74LVC162245Aを候補に含めるが、採用は未決定。

## Scope

- Tang候補の全I/Oではなく、ソケットへ実際に引き出されたユーザI/O数とバンク条件
- Tang Primer 20K SO-DIMMコアボードの204端子表、利用可能I/O、入力専用端子、JTAG/RESET、DDR3占有端子、バンク電圧、コンフィグ時状態
- Tang Mega 138K小型BTB SOMのBTB端子表、コネクタ型番、実効GPIO、バンク、DDR3/Flash/SerDes占有、B/Cデバイス版差、機械高さ
- LVCの入力許容電圧、VCC、VOH/VOL、方向/OE、速度、電流、シリーズ抵抗有無
- Cバス電源からの電源構成、突入、逆流、デカップリング、保護
- PC-98内部FDD系電源の機種別コネクタ/ピン根拠と、補助5 V入力時の選択、逆流防止、ヒューズ、GND、誤接続保護
- 手はんだ試作と製造実装のパッケージ差
- 概算BOMと供給リスク

## Work packages

- [x] Tang候補ごとのモジュール端子・I/Oバンク・DDR・クロック表を作る。
- [x] Tang Primer 20Kについて公式Wikiの117 I/O表記と公式データシートの103 User I/O表記を、SO-DIMM端子表と回路図から照合する。
- [x] Tang Mega 138K BTBについて、非Pro SOMとPro SOMを混同せず、実効GPIO、BTB部品、バンク電圧、SOM電源、B/C版差を照合する。
- [x] 信号グループごとに必要なLVCチャネル、DIR、OEを割り当てる。
- [x] データシート通常動作条件と絶対最大定格を分離して検証する。
- [x] Cバス単独給電を第一候補として消費電流余裕を計算し、不足時のFDD補助5 Vを排他的選択または適切なパワーマルチプレクサで比較する。
- [x] 受動ターゲット版とバスマスタ配線版のBOM/ピン/原価差を算出する。
- [x] 試作推奨案、代替案、未解決リスク、ユーザ判断点をまとめる。

## Completion conditions

- 各候補の必要I/O、I/Oバンク、電圧、方向、速度がデータシート参照付きで判定されている。
- LVCの部品点数とグループ分けが、ターゲット/従来DMA/バスマスタの各構成で示される。
- 手はんだ可能な試作案と、実装サービス向け量産案の違いが見える。
- 概算単価は数量、実装範囲、送料・基板費の前提とともに範囲で示される。
- ユーザが試作構成を選べるだけの比較表がある。

## Expected evidence

メーカー資料、注文可能な型番、取得日付き価格、I/O予算、LVC割当、電源ブロック、BOM概算、比較結果を記録する。

## Candidate baseline

| Candidate | Preliminary evidence | Required verification |
| --- | --- | --- |
| Tang Nano 20K direct | 34 GPIO。訂正後の8-bit I/O最小構成は35本。 | 1本不足するため不採用。 |
| Tang Nano 20K + external I/O aggregation | Nanoを維持できる可能性がある。 | CPLD/レジスタの遅延、方向、High-Z、必要部品数を算出する。 |
| Tang Primer 20K SO-DIMM | `GW2A-LV18PG256C8/I7`、204-pin DDR3 SO-DIMM形状、1 Gbit DDR3、公式Wikiでは117 I/O。 | データシートは103 User I/Oと記載しており要照合。バンク電圧、入力専用端子、電源、ソケット実装を検証する。 |
| Tang Mega 138K BTB | 非Pro SOMは`GW5AST-LV138PG484A`、35 mm×45 mm、1 GB DDR3、BTB接続。 | BTB端子/部品、実効GPIO、バンク電圧、SOM入力電源と消費、B/Cデバイス版、調達性を検証する。Pro版50 mm×70 mmとは分離する。 |
| Tang Nano 20K 8-bit I/O限定 | 独立IORDY/IRQ OEを含め35 GPIO。 | 34 GPIOを超えるため不成立。 |

Tang Primer 20Kの公式データシートは5 V±10%、0.5 Aの電源を要求し、モジュール寸法を67.60 mm×30.00 mmとする。204-pin DDR3 SO-DIMMソケットと機械的に互換だが、DDR3メモリモジュールではないため、通常のメモリソケット配線を流用せず専用キャリア回路を設計する。

公式WikiではBank 0/1/7の既定電圧を3.3 Vとし、変更には抵抗R5/R9の取り外しが必要と説明される。他バンクと全SO-DIMM端子の電圧は回路図・端子表で確認するまで確定しない。

Tang Mega 138Kの予備資料では、非Pro SOMは35 mm×45 mmのBTB構成、`GW5AST-LV138PG484A`、1 GB DDR3とされる。公式資料はIDEで実物に合うDevice Version B/Cを選ぶよう求めているため、同じ商品名でも実チップ版とIDE設定を確認する。Dock側の12 V入力仕様をSOM単体の入力電源仕様とみなしてはならない。

給電は次の優先順位で比較する。

1. Cバス+5 V単独。機種別スロット上限からモジュール、LVC、保護回路、突入を差し引いて余裕を確認する。
2. FDD系+5 V補助。対象PC-98の一次資料またはハーネス実物でピンを確認し、Cバス+5 Vと直接並列接続しない。
3. 外部独立5 V。開発・測定時の代替として評価し、GND接続順と逆給電を管理する。

補助給電用コネクタを基板へ追加する場合は、誤接続防止、極性、ヒューズ/PTC、逆流防止、電源選択表示、挿抜禁止手順を受入条件へ含める。

予備資料:

- Sipeed公式Wiki: <https://en.wiki.sipeed.com/hardware/en/tang/tang-primer-20k/primer-20k.html>
- Sipeed公式データシートV1.0: <https://dl.sipeed.com/fileList/TANG/Primer_20K/01_Specification/Sipeed%20Tang%20Primer%2020K%20Datasheet%20V1.0.pdf>
- Sipeed公式回路図ディレクトリ: <https://dl.sipeed.com/shareURL/TANG/Primer_20K/02_Schematic>
- Sipeed公式サンプル/制約: <https://github.com/sipeed/TangPrimer-20K-example>
- Tang Mega 138K公式Wiki: <https://en.wiki.sipeed.com/hardware/en/tang/tang-mega-138k/mega-138k>

## Interruption and resume record

2026-08-31: Queue `Q20260831-003`で実行し、[component-selection.md](../../ws002-fpga-platform/component-selection.md)を作成した。Primer 204端子とMega 280 BTB端子を機械可読化し、検証スクリプトでPrimer 86本、Mega 144本の保守的3.3 V GPIOを確認した。

初回調査時はPrimerが最大62本profileに24本余ると見積もった。後続`ws001p002` mappingで独立response OEとDMA WORD OEを追加し、DMA/bus-master同時予約を69本へ訂正した。実mapping後もPrimerは17本、Megaは75本残るため選定結果は変わらない。Megaは0.4 mm BTB三点実装と最大消費電流未確認のため工場実装carrierとし、Nano直結は不採用、Nano+CPLDは条件付きとする。

Cバス+5 Vは通常給電とするが、Primerの0.5 A要求は初期機の0.5 A/slot上限と同値である。PC-9800シリーズ全般を目標にするため、キー付き`AUX_5V`、排他選択、逆流/過電流保護、機種別FDD変換ハーネスを推奨した。V13 FDD pinout、Mega非Pro最大電流、実負荷電流、Mega stack heightは未確認のまま次Phase判断点として保持した。

検証: `python3 plan/ws002-fpga-platform/tests/validate_pinouts.py`はPASS。部品比較の目的と完了条件を満たしたためPhaseを`completed`とする。部品の最終採用、回路図、PCB、発注は今回の実行許可外であり未実施。

2026-08-31 post-completion planning decision: ユーザはPrimer 20KとMega 138Kをboard固有top-levelで差し替え、同一のboard-independent `cbus_ip_top`を使用する方針を承認した。[共通IPトップ境界](../portable-top-architecture.md)へ反映した。これは計画同期であり、新たなRTL実装は行っていない。
