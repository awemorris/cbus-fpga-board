# CバスFPGAボード Queue Book

最終更新: 2026-09-01

Queue ID: `Q20260901-009`

Queue status: finished

Parent: [master plan](master.md)

## 1. 現在の実行許可

2026-09-01にユーザが、前Queue完了後の次作業へ進むよう明示的に指示した。

`ws002p002`として、共通`cbus_ip_top`、安全なpad/OE gate、Primer/Mega board top、69 endpointのpackage constraint、iverilog/構造検査を実装・検証する。Gowin実primitive、回路図、PCB、実機試験、memory/DMA/bus-master/IRQ有効化、RISC-Vは含めない。

## 2. Queue作成前の確認事項

- [x] Master Planは承認済みである。
- [x] `ws001p002-resume`で共通69 endpointと両module connector mappingが完了している。
- [x] `ws003p001`から`ws003p003`でCバスtarget、CDC、AXI4-Lite guardが完了している。
- [x] ユーザがPrimer/Megaのboard topだけを差し替え、共通IPを使う方針を決定している。
- [x] RISC-Vは優先順位整理まで後回しである。
- [x] 調査は時間制限なしである。
- [x] `iverilog` 12.0と`vvp` 12.0が利用できる。
- [x] ユーザがQueue完了時または切りのよい境界でのcommitと`git push origin master`を許可した。

## 3. Execution registry

| Order | Queue item | Source | Status | Authorization |
| --- | --- | --- | --- | --- |
| 1 | `ws002p002` | [phase.md](ws002-fpga-platform/phase002-portable-top-safety/phase.md) | completed | 2026-09-01 user requested proceeding |

## 4. 前Queue

- `Q20260831-001`: `ws001p001` completed、Queue finished。
- `Q20260831-002`: `ws001p002` uncleared、Queue finished。34 GPIOでは16-bit以上が不足した。
- `Q20260831-003`: `ws002p001` completed、Queue finished。Primer初回、Mega将来候補を選定した。
- `Q20260831-004`: `ws001p002-resume` completed、Queue finished。共通69 endpointをPrimer/Megaへ割り当てた。
- `Q20260831-005`: `ws001p003` completed、Queue finished。386以降baselineを含むtiming contractを作成した。
- `Q20260901-006`: `ws003p001` completed、Queue finished。CバスI/O target MVPを実装した。
- `Q20260901-007`: `ws003p002` completed、Queue finished。dual-clock CDCとAXI4-Lite bridgeを実装した。
- `Q20260901-008`: `ws003p003` completed、Queue finished。AXI guard/timeout/quarantineを実装した。

## 5. 実行結果

`ws002p002` completed。

- board非依存flat-port `cbus_ip_top`へ既存Cバスtarget、CDC、AXI4-Lite guardを収容した。
- 六つの安全条件を組合せgateする`cbus_pad_adapter`を実装し、不許可時のpad High-Z/LVC OE禁止/DIR receiver側固定を検証した。
- 同じ`cbus_board_shell`をinstantiateするPrimer/Mega topを実装した。production既定はdrive-disabled、raw-clock有効化はsimulation専用parameterとした。
- 未実装local AXI targetをDECERRで有限終了するerror targetへ接続した。memory/DMA/bus-master/IRQの予約portは削らず、drive requestを非assertへ固定した。
- Sipeed公式回路図から両boardの69 endpoint package locationを照合し、onboard clockを含む各70 locationのCST/manifestを生成した。
- `rtl/ip/`以下へのboard/vendor固有名漏出、両wrapper構造同一性、CST一意性を機械検査した。

検証結果:

- `tb_cbus_pad_adapter`: 六安全入力64組、九drive request 512組、即時permit withdrawalを3340 checks PASS。
- `tb_portable_board_tops`: production既定drive-disabled、reset、idle、非選択、選択read/write、power-good低下のPrimer/Mega同値性を15 checks PASS。
- 新規WS002は3355 checks、既存WS003は635 checks、合計3990 HDL checks PASS。
- Primer/Mega constraint、portable-top構造、WS001 signal/platform、WS002 pinout validatorはすべてPASS。
- Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でwarningなし。

外付けOE pull-up、clock停止、configuration中pin state、Gowin device primitive、合成/place-and-route、電気適合、実機High-Zは未検証である。これらを実装・測定するまでboard topは既定drive-disabledのままとし、Cバス実機へ接続しない。

## 6. 今回の実行内容

- flat-port共通IPと二つのboard topを実装する。
- 六条件の安全permitでpad OE/LVC OEを即時gateする。
- 69 endpointとオンボードclockの確認済みpackage CSTを作成する。
- iverilog安全性・top同値試験、mapping構造検査、既存回帰を実行する。
- 実機でのみ確認できる残条件をP/W/Mへ戻す。

状態: 完了。
