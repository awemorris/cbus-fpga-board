# CバスFPGAボード Queue Book

最終更新: 2026-09-01

Queue ID: `Q20260901-010`

Queue status: finished

Parent: [master plan](master.md)

## 1. 現在の実行許可

2026-09-01にユーザが、前Queueのhandoffで提示したAXI-Lite System CSR subordinateとguard fault status統合へ進むよう明示的に指示した。

`ws003p006`として、既存Cバス8-byte窓に対応する四つのSystem CSR、AXI4-Lite protocol、共通IP内統合、Primer/Mega同値BFMを実装・検証する。mailbox、IRQ、DMA、interconnect、fault自動復旧、Gowin/回路図/PCB/実機は含めない。

## 2. Queue作成前の確認事項

- [x] Master Planは承認済みである。
- [x] `ws003p003`でCバス/CDC/AXI guardが完了している。
- [x] `ws002p002`で共通IPとPrimer/Mega board topが完了している。
- [x] Cバス8-byte窓はAXI `+0/+4/+8/+C`の四wordへ固定済みである。
- [x] guard fault clearは同じquarantine済みCバス経路へ置かず、独立復旧経路へ残す。
- [x] `iverilog` 12.0を利用できる。
- [x] ユーザがQueue境界でのcommitと`git push origin master`を許可している。

## 3. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws003p006` | [phase.md](ws003-target-bridge/phase006-system-csr/phase.md) | completed | 2026-09-01 user requested proceeding |

## 4. 前Queue

- `Q20260831-001`〜`Q20260901-008`: WS001/WS002/WS003の調査、Cバスtarget、CDC、AXI guardを実行。
- `Q20260901-009`: `ws002p002` completed。共通IP、安全OE、Primer/Mega top、CSTを実装。

## 5. 実行結果

`ws003p006` completed。

- `PRODUCT_ID=0x4342_cb98`、`VERSION_CAP=0x00ff_0002`、32-bit byte-strobe `SCRATCH`、read-only `STATUS`の四word System CSRを実装した。
- AXI4-Lite AW/W独立buffer、B/R backpressure payload保持、RO SLVERR、範囲外/非word-aligned DECERRを実装した。
- Cバスsticky levelを二段同期し、guard quarantine/sticky/first-fault summaryとSTATUSへ収容した。
- CSRをboard-independent `cbus_ip_top`内でguard下流へ接続し、platform shellの暫定error targetを削除した。
- Primer/Mega topからCバス`base+0/+2/+4/+6`でID、version、scratch、statusが同値になることを検証した。
- guard fault clearは遮断済みCバス経路へ置かず、将来のCPU/debug/platform recovery controllerへ残した。

検証結果:

- 新規`tb_axil_system_csr`: 21 checks PASS。
- 更新`tb_portable_board_tops`: production既定安全、両top同値、System CSR 16/8-bit laneとbackend/guard statusを37 checks PASS。
- WS003 current 656、WS002 current 3377、合計4033 HDL checks PASS。
- Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でwarningなし。
- WS001 signal/platform、WS002 pinout/constraint/portable-top validatorはすべてPASS。

## 6. 今回の実行内容

- 四wordのAXI4-Lite System CSRを実装する。
- 共通`cbus_ip_top`内でguard下流へ接続し、暫定DECERR targetを置き換える。
- standalone AXI BFMとPrimer/Mega Cバス統合BFMを追加する。
- 既存3990 checksと全validatorを回帰する。
- M/W/P/Qを実績へ同期する。

状態: 完了。
