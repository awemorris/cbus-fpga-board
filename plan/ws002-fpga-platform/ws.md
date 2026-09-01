# WS002: FPGA・電気・安全プラットフォーム

最終更新: 2026-09-01

WSID: `ws002`

Status: in-progress

Parent: [master plan](../master.md)

Resume point: `ws002p002`のdrive-disabled board wrapperとCSTを入力に、Gowin clock/config status wrapper、外付けOE pull-up、安全latch、power/DIR/OE回路を回路図へ具体化してから`ws002p003`の段階立上げへ進む。測定器なしではCバス接続試験を開始しない。

## Objective

Tang FPGAモジュール、LVCフロントエンド、電源、クロック、リセット、コネクタを、CバスとPC-98を損傷させず試作・再製造できるプラットフォームとして確立する。

## Scope

- Tangモジュール/FPGA、モジュールソケット、利用可能I/OとDDRの選定
- 16-bit LVCトランシーバを中心とする5 V-CMOS電気境界
- DIR/OE、プル抵抗、直列抵抗、電源シーケンス、デカップリング
- Cバス+5 Vを既定とし、必要時だけPC-98内部FDD系5 Vを使用する補助給電・選択・逆流防止
- クロック、PLL、リセット、コンフィグ完了、安全な出力許可
- ユニバーサル基板試作向け配線・検査・段階的立上げ
- Gowin/Tang固有プリミティブを隔離するvendor wrapper
- Primer 20K/Mega 138Kのboard topだけを差し替え、同一のboard-independent IP topを利用するplatform境界

## Non-goals

- 「5 V tolerant」という名称だけでFPGA直結を許可すること
- データシート最大定格を通常動作条件として使うこと
- このWorkstream内で量産PCBや全Cバス機能を完成すること

## Dependencies

- WS001の信号方向、電圧、タイミング、ピン数。
- WS003/WS006から、ターゲット時とバスマスタ時のDIR/OE状態要求。
- WS008は試作結果、BOM、製造性を入力にする。

## Phase registry

| Phase | Status | Goal |
| --- | --- | --- |
| [`ws002p001`](phase001-component-selection/phase.md) | completed | Tang/LVC/電源/ソケット候補を定量比較し、試作構成案を得る。 |
| [`ws002p002`](phase002-portable-top-safety/phase.md) | completed | `cbus_pad_adapter`、共通IP、Primer/Mega top、CSTと安全プロパティを実装する。 |
| `ws002p003` | planned | ユニバーサル基板試作を組み、電源・High-Z・単方向入力から段階的に立ち上げる。 |
| `ws002p004` | proposed | 温度、電圧、タイミング余裕と長時間安定性を測定する。 |

## Proposed module boundaries

- `tang_primer20k_top`: Primer package pin、constraint、clock/reset/DDR wrapper、LVC物理group、安全OE gateだけを持つ。
- `tang_mega138k_top`: Mega package pin、constraint、clock/reset/DDR wrapper、LVC物理group、安全OE gateだけを持つ。
- `cbus_ip_top`: ボード名と物理pinを持たない共通IPトップ。Cバス論理port、AXI subsystem、CSR、mailbox、DMA、user IP、将来のRISC-Vを収容する。
- `cbus_pad_adapter`: 共通論理`*_i/_o/_oe_req`を扱い、board top側の物理LVC mappingへ渡す。
- `clock_reset_ctrl`契約: board wrapperが生成したclock/reset/statusを共通IPへ渡す。PLL/DDR controller等のprimitiveは`rtl/platform/*`または`rtl/vendor/gowin/*`へ隔離する。

詳細な責務と受入条件は[Primer/Mega共通IPトップ境界](portable-top-architecture.md)を正本とする。共通IP内でboard名による`ifdef`分岐を作らない。

## Completion conditions

- 選定部品が通常動作条件、I/O数、速度、入手性、はんだ付け/実装方法を満たす。
- FPGA未設定時を含め、すべての電源状態でCバスへの意図しない駆動がない。
- ユニバーサル基板試作の配線検査、電源投入、High-Z、入力観測、限定出力試験が再現可能である。
- vendor固有コードが上位RTLのCバス/AXI契約へ漏れない。
- 同じ`cbus_ip_top`を変更せず、Primer/Mega両方のboard targetを選択できる。

## Reconsideration boundaries

I/O数不足、I/Oバンク電圧不成立、コンフィグ中OEが安全に固定できない、LVCの5 V入力条件不成立、手配不能が判明した場合は、部品または機能範囲のユーザ判断へ戻す。
