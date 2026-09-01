# WS008: 専用PCB・製造・頒布

最終更新: 2026-09-01

WSID: `ws008`

Status: proposed

Parent: [master plan](../master.md)

Resume point: 初回試作用にx86ラボ`CB-U04`をユーザが購入済み。入手後に外形、表裏パターン、カードエッジ処理、+5 V/GND、全100端子のland導通を調べ、ユニバーサル基板MVPへ使用できるか確定する。

## Objective

検証済み試作を、組立可能、検査可能、再発注可能で、利用者が安全に扱える専用Cバス基板と頒布パッケージへ変換する。

## Scope

- Cバスコネクタ、LVC、保護、電源、Tangソケットを載せる専用PCB
- Tang Primer 20K SO-DIMMだけを対象とするcarrier、電源、実装、製造データ
- 回路図、layout、stackup、クリアランス、mechanical fit、部品表
- DFM/DFA、PCBA見積り、数量別原価、代替部品、供給寿命
- bed-of-nailsまたは簡易fixture、boundary/continuity/self-test
- reference bitstream、firmware、シリアル/版管理、出荷検査
- 組立、装着、安全、更新、復旧、既知互換性、ライセンス文書
- 小規模pilot頒布と故障/返品/サポートの観測

## Non-goals

- ユニバーサル基板での成功前に量産発注すること
- 部品代だけを完成品原価として提示すること
- 未試験機種への保証、規制・表示・責任範囲を推測すること
- Mega 138K BTB用Cバスcarrierの回路図、PCB、PCBA、製造試験を作成すること。Megaの共通IP/ABI reference supportはWS002/RTL回帰で扱う。

## Dependencies

- WS001〜WS007の凍結済みインターフェース、試験証拠、bitstream、BOM。
- ユーザによる頒布数量、目標原価、実装範囲、保証/サポート方針の判断。

## Prototype hardware on hand / ordered

- x86ラボ `CB-U04`: 購入済み、未受領/未検査。初回Cバスユニバーサル基板候補。
- 公開販売情報ではPC-98/互換機向け、イヤホンとMIDI connector実装対応とされるが、端子表、layer/pattern、電源railは現物確認前に確定としない。
- `CB-U04`の記録はboard-independent共通IP境界を変更しない。Primer 20K primary hardwareの物理試作配線とmechanical fitの入力とする。

## Phase registry

| Phase | Status | Goal |
| --- | --- | --- |
| `ws008p001` | planned after ws002p003/ws003p005 | ユニバーサル基板試作の問題・測定・改版要件を固定する。 |
| `ws008p002` | planned | 専用PCB Rev.Aの回路図、layout、DFM、製造ファイルをレビューする。 |
| `ws008p003` | planned | 少数PCBAを発注し、受入・電気・機械・機能試験を行う。 |
| `ws008p004` | planned | 対象PC-9800互換性、長時間、更新失敗、ESD/取扱リスクを検証する。 |
| `ws008p005` | proposed | BOM、組立、出荷試験、文書、ライセンスを含むpilot頒布判定を行う。 |
| `ws008p006` | proposed | pilot結果をRev.Bと継続頒布判断へ反映する。 |

## Cost model

見積りは少なくとも次を分離する: 裸基板、Cバスコネクタ、LVC/受動部品、Tangモジュール/ソケット、部品調達費、ステンシル、実装費、検査fixture、手直し率、送料、税、予備品、梱包。数量1/5/10/50など同一前提で比較し、見積取得日と実装面/支給品条件を残す。

## Completion conditions

- 製造データから同じ版を再発注でき、BOM代替が電気・firmware互換性を壊さない。
- 全基板がcontinuity、電源、High-Z、reference bitstream self-test、Cバス機能試験を通る。
- 機械干渉、挿抜、コネクタ向き、ブラケット、絶縁が実機で確認される。
- 対象機と未対応機、実験機能、既知問題が購入前に分かる。
- 原価、最低頒布価格、予備/不良率、サポート範囲をユーザが承認する。

## Reconsideration boundaries

電気安全、機械適合、供給、原価、法的/表示要件、互換性のいずれかが頒布基準を満たさない場合は、発注を行わずRev変更または頒布範囲の判断へ戻す。
