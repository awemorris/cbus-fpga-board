# ws001p002: Cバス信号マトリクス

最終更新: 2026-08-31

WSID: `ws001`

Phase ID: `p002`

Combined ID: `ws001p002`

Status: completed

Parent: [WS001](../ws.md)

## Objective

コネクタ、LVC、FPGA物理ポート、論理Cバスポートを一意に対応づけ、安全条件とI/O予算を検証できる信号マトリクスを作る。

## Dependencies and fixed decisions

- `ws001p001`で信頼できるピン・方向・電気情報が得られている。
- 互換目標はPC-9821V13固有ではなくPC-9800シリーズ全般とする。初期実機はV13だが、アドレス幅、データ幅、信号多重化を世代別能力として記録する。
- 論理RTLはCバス信号名を用い、双方向信号は原則 `_i`、`_o`、`_oe` に分ける。
- 物理層はLVCのDIR/OEとFPGA I/O制約を明示し、リセット中High-Zを保証する。

## Scope

- 全コネクタピンの使用/未使用/予約分類
- LVCバンク、方向、OEグループ、電源、プル、直列抵抗候補
- FPGA I/Oバンク、電圧、専用ピン、クロックピン、残余I/O予算
- 受動ターゲット構成とバスマスタ対応構成の差分
- CSV/YAML等の機械可読正本と人間向け表の生成方針

## Work packages

- [x] 信号台帳のスキーマと命名規則を作る。
- [x] CバスピンをLVCグループへ割り当てる。
- [x] Tang候補ごとにI/O、電圧バンク、専用ピンの成立性を確認する。
- [x] reset/config/bus-owned状態ごとのDIR/OE真理値表を作る。
- [x] 回路図・制約・RTLポート間の不一致を検出する照合方法を定義する。

## Completion conditions

- 使用する各Cバスピンが一つの論理ポートと物理経路へ追跡できる。
- 同一LVCバンク内で方向またはOE要件が矛盾しない。
- 候補Tangの利用可能I/Oが、専用/予約ピンを除いて必要数と余裕を満たす。
- 受動のみ、従来DMA対応、バスマスタ対応の三構成で追加ピンと部品差が見える。
- 電源投入・リセット・コンフィグ失敗時のCバス駆動禁止条件が表になっている。

## Expected evidence

信号台帳の版、データシート参照、I/O予算集計、DIR/OE真理値表、照合結果を記録する。

## Execution result

- `signal-matrix.csv`へCバス全100端子、8086/µPD70116型と80286以降型の信号差、方向、極性、出力形式、RTL名、変換器グループを記録した。
- AB00-AB23は両世代表に存在し、物理24線と20-bit互換/24-bitフルデコード能力を分離すべきことを確認した。
- `translator-groups.csv`、`tang-nano-20k-headers.csv`、`io-budget.csv`、High-Z真理値表を作成した。
- Sipeed公式回路図3850/3920/3921/3923を比較し、J5/J6のFPGA I/Oは34本、全端子がオンボード負荷と共有されることを確認した。
- 自動検査で100 Cバス端子、24変換器グループ、40 Tangヘッダ端子/34 GPIO、8 I/Oプロファイルの整合を確認した。
- 独立IORDY/IRQ OEを反映し、8-bit I/O最小構成を33本から35本へ訂正した。Tang Nano 20Kの34 GPIOでは最小構成も収容できない。
- `ws002p001`でPrimer 86 GPIO、Mega 144 GPIOを確認し、本Queueで受動target、選択DMA、286以降bus-masterを同時予約する69 endpointを両方へ割り当てた。Primerは17本、Megaは75本残る。詳細は[共通mapping](../platform-mapping.md)を参照する。
- `platform-endpoints.csv`、`primer20k-platform-map.csv`、`mega138k-platform-map.csv`と再生成/検証scriptを作成した。

## Previous uncleared condition and resolution

Queue `Q20260831-002`ではTang Nano 20KのI/O不足により`uncleared`で終了した。その後、ユーザがPrimer 20K/Mega 138Kをboard固有top-levelで差し替え、同じboard-independent `cbus_ip_top`を使う方針を決定した。

Queue `Q20260831-004`で共通69 endpointと二つのmodule connector mappingを作成した。使用するCバスpathは論理port、translator group、module connector/net、bank、電圧まで追跡できる。IRQ/DMA channelはcarrier selectorという明示的な物理境界へ接続し、機種別pinを共通IPへhard-codeしない。Gowin package pin/CSTとLVC package/octetsは`ws002p002`の実装対象であり、本Phaseのmodule connector契約から分離した。

I/O不足、候補Tangの余裕、受動/DMA/bus-master差、安全OE、機械可読な照合方法の完了条件を満たしたため、本Phaseを`completed`とする。

## Interruption and resume record

2026-08-31: Queue `Q20260831-002`で開始。ユーザ指示によりPC-9800シリーズ全般を互換目標とし、24-bitアドレスが286以降かを一次資料で再確認した。

2026-08-31: Tang Nano 20KのI/O不足を確認。信号台帳と検証可能な成果は保存し、モジュール/外部集約/機能限定の判断を推測せず`uncleared`で終了した。

2026-08-31: Queue終了後の計画判断として、Primer/Mega二つのboard topと一つの共通IP topを採用した。物理mappingを二種類作る再開条件が成立したが、新Queue未承認のため実装・mapping作業には未着手。

2026-08-31: Queue `Q20260831-004`で再開。IORDY/IRQ/WORDの独立OE不足を発見してI/O予算を訂正し、受動target、選択DMA一経路、286以降bus-master予約を含む69 endpointをPrimer/Megaへ割り当てた。全自動検査がPASSしたため`completed`。
