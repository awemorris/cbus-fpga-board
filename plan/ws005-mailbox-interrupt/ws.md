# WS005: メールボックス・割り込み

最終更新: 2026-09-01

WSID: `ws005`

Status: in-progress (p002 completed)

Parent: [master plan](../master.md)

Resume point: `ws005p002`でstandalone mailbox/router RTLと自己検査BFMを完了した。RISC-Vと実機IRQを待たずに続ける場合は、`ws005p005`のAXI fabric/Cバス相対alias/`cbus_ip_top`統合を実行可能なP書へ詳細化する。

## Objective

PC-98、RISC-V CPU、DMA、ユーザIPのイベントを、通常レジスタアクセスと明確に分離したメールボックスと割り込み機構で通知する。

## Scope

- Host-to-CPUとCPU-to-HostのデータFIFOまたはmailbox register
- H2C/C2H doorbell、pending、mask、W1C acknowledge
- CPU IRQ集約とCバスIRQ出力
- overflow、underflow、重複doorbell、reset時の意味論
- AXI4-Lite CSR、CバスI/O公開窓、ファームウェアdriver
- 将来の監視レジスタwrite-event FIFOを追加できる拡張点

## Non-goals

- すべての公開レジスタwriteを自動的にIRQへ変換すること
- IRQ番号、I/Oポート番号を根拠や競合調査なしに固定すること
- 高帯域データをmailboxだけで転送すること

## Dependencies

- WS003のCバスI/O/AXI4-Lite経路。
- WS004のCPU IRQ入力とCSRアクセス。
- WS001のCバスIRQ電気・タイミング契約。
- WS006/WS007はイベントsourceを割り込みrouterへ接続する。

## Phase registry

| Phase | Status | Goal |
| --- | --- | --- |
| [`ws005p001`](phase001-register-contract/phase.md) | completed | mailbox/doorbell/IRQのレジスタと状態遷移を固定する。 |
| [`ws005p002`](phase002-mailbox-router-rtl/phase.md) | completed | mailbox FIFO、interrupt router、W1C/maskをstandalone RTL実装する。 |
| `ws005p003` | planned | RISC-V driverとPC-98診断プログラムで双方向通知を検証する。 |
| `ws005p004` | proposed | 必要性が実証された場合だけ監視write-event FIFOを追加する。 |
| `ws005p005` | planned; needs Phase Book | AXI fabric/Cバス相対aliasと共通IPへ統合し、polling BFMで検証する。 |

## Completion conditions

- PC-98がmailboxへデータを書きdoorbellを鳴らすと、CPUが一回以上確実に認識してackできる。
- CPUからPC-98への通知も、選択したIRQ線またはpollingで取りこぼしなく処理できる。
- 通常CSR書込みはdoorbellでない限り不要なIRQを発生させない。
- pending、mask、W1C、FIFO full/empty、reset競合が形式化されたテストで通る。

## Reconsideration boundaries

対象機で安全に使えるIRQ/ポート資源が確保できない場合は、設定方式またはpolling-only初版をユーザ判断へ戻す。
