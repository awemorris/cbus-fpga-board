# WS007: ユーザIP SDK・サンプル

最終更新: 2026-08-31

WSID: `ws007`

Status: proposed

Parent: [master plan](../master.md)

Resume point: AXI address map、IRQ、DMA APIが安定後に最初のユーザIPテンプレートを詳細化する。

## Objective

ユーザがAI生成を含む独自RTLとRISC-Vファームウェアを、安全な境界内で追加し、ビルド、シミュレーション、実機診断できる開発キットを提供する。

## Scope

- `user_region_wrapper`と安定した`generated_user_top`契約
- AXI4-Lite subordinate、IRQ、DMA request、optional AXI-Stream
- 必要時だけ許可するguarded AXI Manager、timeout、region firewall
- register map/driver定数生成、lint、CDC、simulation harness
- 最小CSR、FIFO/IRQ、DMA loopbackのサンプルIP
- RISC-V SDK、driver、diagnostic、bitstream build手順
- SCSI/USBデバイス連携へ進むための代表サンプル計画

## Non-goals

- ユーザRTLへ生のCバスピン、LVC DIR/OE、無制限AXI accessを公開すること
- AI生成コードをレビュー・検証なしに実機bitstreamへ入れること
- 初版で全SCSI機能・全USB classを完成すること

## Dependencies

- WS003のCバス/AXI-Lite、WS004のSoC/toolchain、WS005のIRQ、WS006のDMA。
- WS008の頒布物はSDK版とreference bitstreamを固定する。

## Phase registry

| Phase | Status | Goal |
| --- | --- | --- |
| `ws007p001` | planned | ユーザIPのポート、clock/reset、address、IRQ、DMA、安全制限を固定する。 |
| `ws007p002` | planned | テンプレート、生成定数、lint/CDC、BFM、ビルドを作る。 |
| `ws007p003` | planned | CSR + FIFO/IRQ + DMA loopbackサンプルとdriverを作る。 |
| `ws007p004` | proposed | ソフト主体のSCSIコントローラ/エミュレーション例を作る。 |
| `ws007p005` | proposed | USBホスト/デバイス連携の代表例を作る。 |

## Completion conditions

- 第三者がクリーン環境からテンプレートIP、firmware、bitstreamを構築できる。
- 不正address、無応答、IRQ storm、DMA範囲違反がfabric/Cバス全体を停止させない。
- サンプルがシミュレーションとreference boardで同じregister contractを満たす。
- AI生成RTLを投入する前後のレビュー項目と自動ゲートが文書化される。

## Reconsideration boundaries

ユーザIPにAXI Managerを許すことが安全性または資源目標と両立しない場合は、AXI-Lite + stream/DMA requestだけへ制限する判断をユーザへ戻す。
