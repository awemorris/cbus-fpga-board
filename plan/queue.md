# CバスFPGAボード Queue Book

最終更新: 2026-08-31

Queue ID: `Q20260831-004`

Queue status: finished

Parent: [master plan](master.md)

## 1. 現在の実行許可

2026-08-31にユーザが、直前に提示した「`ws001p002`を再開し、Primer/Mega両方の物理端子マッピングを作る」次Queueを「実行してください」と明示的に承認した。

共通`cbus_ip_top`の論理endpoint集合を定義し、Primer 20KとMega 138Kの保守的3.3 V GPIOへ、同じendpointを重複なく割り当てる。24-bit/16-bit受動target、選択式IRQ、従来DMA一経路、286以降型bus-master予約を収容し、各機能の実装有効化は行わない。RTL、constraint、回路図、LVC回路、PCB、発注、実機測定は含めない。

## 2. Queue作成前の確認事項

- [x] Master Planは承認済みである。
- [x] `ws001p001`と`ws002p001`は完了し、`ws001p002`の信号台帳と両モジュール端子表が利用できる。
- [x] ユーザがPrimer/Mega board top差し替えと共通IP top方針を決定した。
- [x] ユーザが直前に提示した次Queueの実行を明示的に指示した。
- [x] 調査は時間制限なしである。

## 3. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws001p002-resume` | [phase.md](ws001-cbus-contract/phase002-signal-matrix/phase.md) | completed | 2026-08-31 user approved the next Queue described in the previous handoff |

## 4. 前Queue

- `Q20260831-001`: `ws001p001` completed、Queue finished。
- `Q20260831-002`: `ws001p002` uncleared、Queue finished。34 GPIOでは16-bit以上が不足し、構成選択を`ws002p001`へ差し戻した。
- `Q20260831-003`: `ws002p001` completed、Queue finished。初回Primer、将来Megaを推奨し、その後ユーザが両board topを共通IPへ接続する方針を決定した。

## 5. 実行結果

`ws001p002-resume` completed。

- IORDY/IRQ OEとDMA WORD OEの独立性を反映し、I/O予算を訂正した。Nanoは8-bit最小でも35本対34本で不成立。
- 24-bit address、16-bit data、I/O/memory target、選択IRQ、選択DMA一経路、286以降型bus-master予約、9本の安全DIR/OEからなる69 endpointを作成した。
- Primer SO-DIMMへ69 endpointを割り当て、86本中17本を残した。
- Mega BTBへ同じ69 endpointを割り当て、144本中75本を残した。
- PrimerではBank 0/2をaddress、Bank 7をdata、Bank 1をその他Cバスpath、Bank 3をLVC制御へ使用した。
- MegaではBank 2をaddress、Bank 3をdata、Bank 4をその他path/LVC制御へ使用した。
- IRQ/DACK/DRQは機種・slot差を共通IPへ持ち込まず、carrier selector境界とした。selector回路方式は未確定で、Cバスpin同士の直結は許可しない。
- 今回のbus-master予約は286以降型のEXHRQ/EXHLA/SBUSRQに限定し、8086型の多重機能を同じ電気pathで有効化しない。

検証結果:

- `validate_signal_matrix.py`: 100 Cバスpin、24 translator group、8 I/O profile PASS。
- `validate_platform_maps.py`: 両board 69 endpoint、一意pin、3.3 V通常GPIO限定、bank、残余数 PASS。
- `validate_pinouts.py`: Primer 204端子/86 GPIO、Mega 280端子/144 GPIO PASS。

成果物: [共通mapping説明](ws001-cbus-contract/platform-mapping.md)、[endpoint正本](ws001-cbus-contract/platform-endpoints.csv)、[Primer mapping](ws001-cbus-contract/primer20k-platform-map.csv)、[Mega mapping](ws001-cbus-contract/mega138k-platform-map.csv)。

Queue内の許可作業を検証まで完了した。RTL、CST、回路図、LVC package割当、PCB、発注、実機測定は実施していない。

## 6. 今回の実行内容

実行内容:

- 共通endpoint集合と機能profileを機械可読化する。
- 受動target応答の独立OE、従来DMAのWORD OE、bus-master用address/command DIR/OEをI/O予算へ反映する。
- Primerではaddress/data/other/controlをbank単位でまとめ、86本の保守的GPIO内へ重複なく割り当てる。
- Megaでも同じendpointをBank 2/3/4へ割り当てる。
- reserved/config/JTAG/1.5 V input-only/SerDes/ADC/Bank 5を割当に使用しない。
- 自動検査でendpoint集合、Cバス台帳参照、両boardのpin一意性、bank、3.3 V、残余GPIOを確認する。
- `ws001p002`とM/W/Pを実績へ同期する。

状態: 完了。
