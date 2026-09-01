# ws004p001: RISC-V SoC IP要件・コア選定基準

最終更新: 2026-09-01

WSID: `ws004`

Phase ID: `p001`

Combined ID: `ws004p001`

Status: planned; ready for research Queue proposal

Parent: [WS004](../ws.md)

## Objective

基板、DDR controller、特定Tang品種の実装より先に、CバスFPGA IP全体へ必要なRISC-V CPU/SoCの機能、ABI、boot/reset、bus、interrupt、memory、toolchain、資源条件を定義し、後続RTLが参照できるコア選定基準とreference SoC契約を作る。

## Scope

- 必須/任意RISC-V ISA拡張、privilege、例外、interrupt、timer、debug要件。
- CPU側AXI4/AXI4-Lite manager境界、outstanding、unaligned、error/timeoutの扱い。
- reset vector、boot ROM、on-chip RAM、firmware image、再書込み/復旧方法。
- System CSR、mailbox、interrupt router、DMA、user IP、将来host apertureとのmemory map/ownership。
- キャッシュ/coherency/atomicの初期方針とDMA共有領域。
- clock/reset/CDC、simulation、formal/assertion、synthesis portabilityの要件。
- GCC/LLVM/binutils等toolchain、license、再現build、BSP、diagnostic firmwareの受入条件。
- 候補soft coreの一次資料に基づく比較と推奨案。
- Primer 20Kを資源上限のprimary reference、Mega 138Kを論理interface referenceとするが、共通IPにboard名を持ち込まない。

## Excluded

- RISC-V core、interconnect、boot ROM、firmwareの実装。
- Gowin DDR/PLL primitive、Primer DDR pin、timing closure、bitstream生成。
- Mega carrier/PCB/実機SoC受入。
- Linux、MMU、cache coherency、高性能SMPを初版必須にすること。
- 候補比較なしにライセンス/保守性不明のコアを確定すること。

## Required outputs

- `riscv-soc-requirements.md`: MUST/SHOULD/MAY、根拠、検証方法、後続Phaseの対応先。
- `riscv-core-comparison.csv`: ISA、bus、interrupt、debug、license、toolchain、simulation、資源/Fmax公開値、maintenance、integration effort。
- `riscv-boot-reset-contract.md`: reset domains、vector、ROM/RAM、image layout、fault/recovery、observable boot stages。
- `soc-memory-map.md`または既存Master mapの詳細契約: owner、access、cacheability、side effect、未割当region。
- `soc-interface-contract.md`: CPU manager、AXI-Lite CSR、IRQ vector、clock/reset、reference memory model。
- コア推奨案、代替案、ユーザ判断が必要な残点。

## Requirements questions to resolve

### CPU and ISA

- RV32を初期基準とする妥当性、`I/M/C`等の必須/任意区分。
- machine modeだけで足りるか、CSR/exception/interruptに必要な最小privilege。
- misaligned access、illegal instruction、bus error、watchdog/resetの可観測性。
- stable upstream、license、改変配布、vendor lock-in、Icarus/Verilator等での検証可能性。

### Bus and memory

- CPU instruction/data interfaceをAXI4へ直接するか、native bus adapterを許容するか。
- 初期outstanding上限、burst、ID幅、32-bit data/address、AXI4-Lite bridge境界。
- DDRなしでも進められるbehavioral memory/BRAM reference targetと、後のPrimer DDR targetの同一interface。
- 初期はcache disabledまたはDMA共有領域non-cacheとし、cache/coherencyを後続へ隔離する条件。
- Cバス由来Managerからhost apertureへの再入禁止と、CPU/DMAだけに許すroute policy。

### Boot, firmware and diagnostics

- reset vector、immutable ROM、mutable RAM、firmware link address、stack、trap vector。
- boot stageをSystem CSR/mailbox/UART等から観測する方法。UARTを必須物理依存にしない。
- firmware ABI header、linker script、startup、trap、MMIO access、mailbox loopbackの最小成果。
- toolchain version lock、build script、binary/ELF/mapの生成、clean build再現性。

### Interrupt and control

- `ws005p001`の32-source logical routerをCPU interruptへ接続する方式。
- mailbox、guard fault、DMA、user IRQ、timer、software interruptのpriority/ack/level-pulse変換責務。
- debug halt中またはCPU reset中でもCバスtarget/mailboxが安全に動く独立性。

## Selection process

1. 要件をMUST/SHOULD/MAYとacceptance testへ変換する。
2. 少なくとも複数の現行候補を公式repository/documentation/licenseで比較する。
3. Primer 20Kの公開資源上限に対する保守的budgetを作り、core単体だけでなくfabric/BRAM/mailbox/DMA余白を含める。
4. vendor-neutral simulationと、必要ならGowin synthesis可否を別列で評価する。
5. reference core推奨案と代替案を記録する。製品スコープや配布条件を変える選択はユーザ判断へ戻す。

## Initial acceptance principles

- reference SoCはDDRなしのbehavioral memoryまたはon-chip RAMで全RTL/firmware回帰を実行できる。
- CPU reset/停止がCバスinput pathのHigh-Z安全性を壊さない。
- AXI error/timeout/illegal accessでCPU/fabricが無限停止せず、trapまたはdiagnostic stateを観測できる。
- CPUがSystem CSR、mailbox/router、将来DMA/user IPへowner policyどおりアクセスできる。
- firmwareとRTL ABIは機械可読定数から生成または照合される。
- Primer DDR wrapperは同じmemory target契約へ後付けでき、共通IPにGowin primitiveを入れない。

## Work packages

- [ ] 既存M/WS003/WS005/WS006/WS007からSoC要求と未解決点を抽出する。
- [ ] MUST/SHOULD/MAYとacceptance testを作成する。
- [ ] core/toolchain/license/maintenance/interface候補を一次資料で比較する。
- [ ] boot/reset、memory map、CPU bus、IRQ、reference memory interfaceを契約化する。
- [ ] Primer向け保守的resource budgetとboard-independent境界を作る。
- [ ] 推奨core/代替案、残る人間判断、後続p002/p004のentry条件を提示する。
- [ ] M/W/Pへ優先順とDDR/physical defer方針を同期する。

## Verification

- 各MUST要件に検証方法と後続Phaseが割り当てられている。
- memory mapにoverlapがなく、各regionにowner、bus種別、cacheability、error policyがある。
- boot/reset stateは有限で、失敗時の観測・復旧条件がある。
- core比較のlicense/interface/resource/toolchain欄にsourceがあり、unknownを空欄で隠さない。
- board-independent reference memoryとPrimer DDR wrapperの境界が同一interfaceで説明できる。
- `ws004p002`と`ws004p004`を重要な設計発明なしに詳細化できる。

## Completion conditions

- RISC-V/SoC IPの要件、acceptance、interface、boot/reset、memory mapがレビュー可能な文書になっている。
- 候補コアの比較と推奨案が、license、再現性、資源、統合リスクを含む。
- DDR/PCB/実機を待たずにreference SoC RTLへ進めるentry条件が定義されている。
- product scopeや配布条件に関わる未解決選択は明示され、実装で暗黙決定されない。

## Interruption and resume policy

- 候補のlicense、配布条件、maintenanceが確認できない場合は採用扱いにせず代替候補を残す。
- 公開資源値がない場合は推測値を確定値にせず、後続の最小合成probeを再開条件にする。
- core選択がユーザの製品方針を変える場合は、比較と推奨までで止めて判断を求める。
- DDR/board情報が不足していてもreference memory要件の詳細化は継続する。
