# WS006: DMA・Cバスバスマスタ

最終更新: 2026-08-31

WSID: `ws006`

Status: planning

Parent: [master plan](../master.md)

Resume point: AXI DRAMとCSRが安定した後、ローカルDMAから段階的に実装する。

## Objective

CPUがMMIOで制御でき、ユーザIP・DRAM・PC-98間のデータ移動を安全に行うDMA基盤を、リスクの異なる三つのモードへ分離して提供する。

## Scope

- 共通 `dma_csr`、command FIFO、scheduler、status/error/IRQ
- AXIローカルcopy/stream DMA
- PC-98側DMACがアドレス/カウントを管理する従来8237型DMA endpoint
- FPGAがCバス所有権を得る外部バスマスタDMA
- AXI上のPC-98 memory/I/O apertureとアクセスguard
- timeout、abort、境界、部分転送、reset recovery、性能計測

## Non-goals

- 三DMAモードを一度に実装すること
- Cバス受動要求をhost apertureへ再帰的に転送すること
- 機種別根拠なしにバスマスタ調停を有効化すること

## Dependencies

- WS001の従来DMA/バスマスタ信号とタイミング。
- WS002の双方向アドレス・データ・制御LVCと安全OE。
- WS003のCバスターゲット経路、WS004のDRAM/fabric、WS005のIRQ。

## Phase registry

| Phase | Status | Goal |
| --- | --- | --- |
| `ws006p001` | planned after ws004p003 | AXIローカルDMA、CSR、descriptor、IRQをDRAM/FIFO間で検証する。 |
| `ws006p002` | planned | `DRQ/DACK/TC/WORD`等による従来DMA endpointをBFMで検証する。 |
| `ws006p003` | planned | 従来DMAを実機で低速・小転送から検証する。 |
| `ws006p004` | proposed | `cbus_bus_owner`と`cbus_master_engine`をBFMで実装する。 |
| `ws006p005` | proposed | protected host aperture経由の実機バスマスタDMAを検証する。 |

## Proposed module boundaries

```text
dma_subsystem
  dma_csr
  dma_command_fifo
  dma_scheduler
  axi_copy_engine
  legacy_8237_dma_engine
  dma_error_irq

cbus_subsystem
  cbus_bus_owner
  cbus_master_engine
  axi_to_cbus_bridge
```

## Completion conditions

- 各DMAモードが独立してenable/disableでき、未実装モードはCバスを駆動しない。
- CPUがMMIOで開始、進捗、完了、転送量、失敗理由を観測できる。
- 長さ0、奇数長、境界跨ぎ、timeout、abort、reset、backpressureに決定的な挙動がある。
- バスマスタはgrant取得後だけアドレス/制御を駆動し、解放順序とOEガードがassertionで守られる。
- 実機DMAは対象機、転送方向、サイズ、速度、波形、データ照合結果を記録する。

## Reconsideration boundaries

対象機で外部バスマスタの公開根拠または安全な調停が確認できない場合、初版は従来DMAまでとし、バスマスタ配線/機能を非搭載または実験扱いにする判断をユーザへ戻す。
