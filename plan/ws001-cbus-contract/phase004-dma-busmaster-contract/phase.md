# ws001p004: 従来DMA・外部バスマスタ契約

最終更新: 2026-09-01

WSID: `ws001`

Phase ID: `p004`

Combined ID: `ws001p004`

Status: planned; ready for research Queue proposal

Parent: [WS001](../ws.md)

## Objective

386以降のPC-9800シリーズについて、従来DMA endpointと286以降型外部バスマスタを混同せず、WS006のboard-independent BFM/RTLが参照できる調停・転送・停止・安全契約を作る。

## Scope

- `DRQ/DACK/WORD/DMATC`による従来DMA endpointの要求、ack、byte/word、terminal count、abort。
- `EXHRQ1/2`、`EXHLA1/2`、`SBUSRQ`による外部バス所有権の要求、許可、解放、再取得。
- grant後にだけ駆動できる`AB/BHE/DB/IOR/IOW/MRC/MWC/MWE/SALE`の所有権境界。
- reset、POWER無効、platform未ready、grant消失、`SBUSRQ`、timeout時のHigh-Z復帰。
- 386/486/Pentium資料profileの共通点と差分、チャネル/スロット依存事項、未確認事項。
- BFM/RTL向けの機械可読cycle/state/parameter契約とvalidator。

## Excluded

- DMA、bus owner、AXI-to-C-bus bridge RTLの実装。
- DRQ/DACK/IRQの実機チャネル番号、jumper/DIP、Cバス物理配線の決定。
- Primer carrier、LVC回路、PCB、Gowin合成、実機駆動・測定。
- 8086/70116/80286固有実装。資料上の差は記録するが初期acceptanceに含めない。
- 公開根拠または実測なしにV13固有互換性を確定すること。

## Inputs and evidence policy

- [`evidence.md`](../evidence.md)の`C-DMA-*`、`C-MASTER-*`と未確認IDを起点にする。
- [`signal-matrix.csv`](../signal-matrix.csv)を信号名、方向、電気方式の正本にする。
- NEC一次資料の外部DMA/外部CPUタイムチャートを画像で照合し、OCRや二次記事だけから数値を確定しない。
- family-confirmed、target-confirmed、inferred、unknownを分離する。V13または任意のPC-98へ無条件に外挿しない。
- 各定量値は適用profile、単位、最小/最大、source page、confidenceを持つ。

## Required contract artifacts

- `dma-master-cycle-contract.csv`: サイクル、step、主体、信号状態、sample/drive/release条件、適用profile、根拠。
- `dma-master-timing-parameters.csv`: 要求、許可、data/address、terminal count、releaseに関する定量値。
- `dma-master-state-contract.md`: 従来DMAとbus ownerの独立state machine、安全不変条件、timeout/abort。
- `dma-master-capability-matrix.csv`: 世代、モード、信号、資料上の対応、実機確認状態。
- `tests/validate_dma_master_contract.py`: 信号参照、必須状態遷移、source/status/unit、High-Z終端の整合検査。

ファイル名は実行時に既存命名規則との整合で微修正してよいが、同じ情報を人手記述だけに閉じ込めない。

## Contract boundaries

### Legacy DMA endpoint

- カードは選択された一経路の`DRQ`だけを要求し、`DACK`前には転送成立とみなさない。
- `WORD`は独立OEを持ち、word転送を示す期間だけDACKと同期して駆動する。
- `DMATC`は最終byte/wordを示すlevelとしてsampleし、edgeだけに依存しない。
- byte/wordとDB lane、転送方向、IORDY、DACK中断、resetの意味をcycleごとに定義する。
- 物理チャネル番号とslot多重はcapabilityとして分離し、共通RTLへ固定値を埋め込まない。

### External bus master

- `EXHRQ1/2`のpriorityは資料根拠に従って別profile化し、推測で同等に扱わない。
- 対応する`EXHLA`が有効になるまではaddress/data/command OEをassertしない。
- grant中でもreset、POWER無効、platform未ready、`SBUSRQ`、選択grant消失を最優先のrelease原因とする。
- releaseはcommand/data/addressを安全順にinactive/High-Zへ戻し、その後requestを解除する契約候補を資料と照合する。順序が資料から確定しなければunknownとしてWS006の保守的assertion候補を併記する。
- passive targetとactive masterのrequestを一つのOE state machineへ混ぜない。

## Work packages

- [ ] 一次資料のDMA、外部CPU/DMA、IORDY、bus release波形と注記を再確認する。
- [ ] 従来DMAのcycle/state/timing契約を作成する。
- [ ] 外部バス所有権とmaster read/writeのcycle/state/timing契約を作成する。
- [ ] 386/486/Pentiumとチャネル/slot差をcapability matrixへ分離する。
- [ ] すべてのdrive状態にgrant/platform/reset条件とHigh-Z終端を割り当てる。
- [ ] validatorを追加し、signal/timing契約との相互参照を検査する。
- [ ] WS006のp002/p004を詳細化可能にする入力と、実機まで残るunknownを同期する。

## Verification

少なくとも次を自動検査する。

- 契約中の全信号がsignal matrixに存在し、方向とactive levelが矛盾しない。
- 各cycleに開始、所有者、sample/drive、正常終了、abort、reset/High-Z終端がある。
- bus-master drive stepは必ず対応grant状態を必要とする。
- `SBUSRQ`、grant消失、reset、platform-not-readyから有限stepで全OE offへ到達する。
- 従来DMAと外部bus masterの状態・信号・timeoutを同一サイクル名へ潰していない。
- 定量値にsource、profile、unit、confidenceがあり、unknownを0や仮値で代用していない。

再現コマンドはPhase実行時に確定し、最低限既存WS001 validatorと新validatorを一括実行する。

## Completion conditions

- 従来DMAと外部バスマスタそれぞれのBFMを、人間判断なしに実装できるstate/cycle契約がある。
- grant前無駆動、`SBUSRQ`/reset/abort時release、terminal count、byte/wordの不変条件が機械検査できる。
- 386以降のfamily-level根拠と、V13/slot/channel固有の未確認事項が分離されている。
- `ws006p002`と`ws006p004`のboard-independent RTL Phaseを詳細化できる。
- 物理DMA/バスマスタを有効にしなくても本Phaseを完了できる。

## Interruption and resume policy

- 一次資料間でdrive/release順序が矛盾する場合は推測せず、矛盾・安全側候補・必要実測を記録して該当部分を`uncleared`とする。
- target固有資料がないことだけを理由にfamily contract全体を止めない。実機依存列をunknownのまま保持する。
- RTL、回路、physical enableが必要になった場合は本Phaseを拡大せず、WS006またはWS002の後続Phaseへ戻す。
