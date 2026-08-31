# Cバス受動ターゲット・タイミング契約

最終更新: 2026-08-31

対象Phase: [`ws001p003`](phase003-timing-contract/phase.md)

機械可読な正本は [timing-profiles.csv](timing-profiles.csv)、[timing-parameters.csv](timing-parameters.csv)、[cycle-contract.csv](cycle-contract.csv) である。本書は設計上の意味と未確認境界を説明する。

## 1. 結論

PC-9800シリーズのCバスを一つの同期bus profileとして扱ってはならない。S001は約4.9152、7.9872、9.8304 MHzのSCLKを示すが、CPU世代・modeごとにread/write deadline、data hold、標準waitが異なる。特に80286 12 MHz動作時はSCLKがCPU clockと同期せず、資料自身がタイミング基準として使用できないとしている。

したがって共通`cbus_ip_top`は次を前提にする。

- Cバス入力を内部AXI clockと同一domainだと仮定しない。
- board topが選ぶ機種profileを、bus target engineのtiming parameterへ渡す。
- SCLK edgeだけでstrobes/dataを一発sampleする実装を禁止し、12 MHz profileを含む非同期captureをWS003で検証する。
- DB、IORDY、IRQの出力許可はcycle engineのrequestに加えてplatform ready/reset/clock lock/bus permitでgateする。

## 2. 世代profile

`timing-profiles.csv`は8086-class、70116系、80286/386、486/Pentiumを分離する。CPU clock名ではなく、Cバスへ実際に出るSCLK periodとsource timing表をprofileの正本にする。80286 12 MHz profileの`invalid_unsynchronized`は、周波数値が存在してもSCLK edgeをcycle判定へ使用できないことを表す。

初期の設計・互換性試験・保証対象はユーザ判断により386以降とする。8086-class、70116系、80286固有条件は消さず`record_only`として保存する。80286/386共通表は80386に適用する場合だけ`target_386_only`、486/Pentium表は`target`とした。これにより古い世代差を設計から無理に吸収せず、将来対応の調査資産は失わない。

S001 p.321による対応は次の通りである。

- 80386 16 MHzは8 MHz mode相当のCバスクロック。
- 80386 20 MHzは10 MHz mode相当。
- 80286 12 MHzは10 MHz mode相当のSCLKを出すがCPUとは非同期。
- 486/Pentium表は101.73 ns cycleを示す。
- PC-9801FA、US、XA/XL等には表中の例外値がある。CSVのnotesに残し、一つの「最悪値」へ無断で丸めていない。

V13は1996年機でS001の直接対象外である。486/Pentium profileはV13向け初期シミュレーション候補にできるが、互換保証値ではない。S001の範囲では486/Pentiumも80286/386と同じ後期型signal/cycle familyにあり、全面的に異なるprotocolは確認されない。数値profileと機種例外で扱い、後続一次資料または実測でsignal意味、strobe順序、wait/IRQ方式に不連続が見つかった場合にアーキテクチャを再検討する。

## 3. I/O read/write

I/O cycleは下位16-bit address、`AB001`、`BHE0`と`IOR0`/`IOW0`で認識する。

Readでは、カードはdecode一致かつ`IOR0` Lowを確認するまでDBをHigh-Zに保つ。応答するlaneだけをdriveし、profileのread deadlineまでにvalidにする。`IOR0`がHighへ戻った後もprofileのholdを満たし、それからHigh-Zへ戻す。

WriteではDBを常時入力とし、`IOW0` Low中のsource valid windowで選択laneをcaptureする。内部clockへどうcaptureするかはWS003のBFMで決めるが、NEC表のhold余裕をCDC段数で使い切ってはならない。

## 4. Memory read/write

80286以降型の24-bit memory decodeでは`AB171-AB231`を`SALE1`でlatchし、`AB001-AB161`と組み合わせる。旧20-bit board互換と24-bit full decodeは設定profileを分ける。

Readは`MRC0`、write cycleは`MWC0`で認識し、実際のmemory write timing qualifierとして`MWE0`も使用する。Read DB drive/releaseはI/O readと同じHigh-Z原則に従う。Writeで`MWC0`だけを見て書き込む実装は禁止する。

S001のmemory表に現れる負値は、図の基準edgeに対する座標であり「負の遅延」ではない。CSVでは原値を保持し、絶対deadlineへ推測変換していない。WS003のBFMはsource chartのedge関係をそのまま再現する。

## 5. IORDY wait

`IORDY1`はカード側tri-state出力で、Lowがwait要求、通常はHigh-Zである。S001 p.297はLow幅を最大7 usとする。p.329の70116以降共通CPU入力タイミングは、Low幅40 ns以上、commandからwait assertionまで最大80 ns、release setup 30 ns以上（PC-98XAは37 ns）を示す。

安全契約は次の通り。

- 応答がprofile deadlineを満たす場合はIORDYをdriveしない。
- waitが必要なら許可されたwindow内にLowへし、ready後にreleaseする。
- Lowを7 usより長く保持しない。backend timeout時もIORDYを解放し、faultを観測可能にする。
- Highを積極driveせず、外付け回路を含むHigh-Z/releaseを基本とする。

初期PC-9801群は別の`IORDY Inactive/Active Setup`表を持つため、後期共通80/30 ns値だけで全世代を宣言しない。

## 6. IRQとINTAの境界

S001 p.296はIR3/5/6/9/10/11/12/13系を正エッジ要求とする。IR9系はopen collector+pull-up、他はtri-state bufferである。したがってIRQ番号を固定せずcarrier selectorで一線を選び、選択外線は常にHigh-Zとする。

S001は要求に必要なLow pulse widthを定量規定していない。positive edge、host側INT応答最大370 nsは確認できるが、370 nsをcard pulse widthへ流用してはならない。exact pulse/release sequenceはPIC資料または代表機実測を再開条件とする。

`INTA0`は受動拡張カードへのinterrupt acknowledgeではない。80286以降型のA37にあり、外部CPUがバス所有権を得た場合のdrive信号としてS001 p.303に列挙される。8086型では同じpinが`S00`であるため、受動target engineは使用せず`ws001p004`へ送る。

## 7. 実装へ渡す不変条件

- Reset、configuration中、clock未確立、profile不明、decode不一致ではDB/IORDY/IRQをHigh-Zにする。
- Read DBはcommand認識前にdriveせず、command終了後のholdを満たしてからreleaseする。
- Write DBはcard側からdriveしない。
- IORDYとDB OEは独立制御し、waitだけ必要なcycleとdataだけdriveするcycleを表現できるようにする。
- IRQ OEはDB/IORDYと独立し、選択外IRQへは絶対に接続・driveしない。
- 12 MHz 80286 profileを含め、SCLK同期だけに依存しないテストを必須にする。

## 8. 未確認事項と再開条件

| ID | 未確認事項 | 今回の扱い | 再開条件 |
| --- | --- | --- | --- |
| `T-U001` | V13の実SCLK、strobe、wait、hold | 486/Pentium profileは候補のみ | 5 V対応logic analyzer/oscilloscopeで対象slotを測定 |
| `T-U002` | LVC、配線、FPGA I/Oを含む遅延budget | 数値から差し引かない | 部品確定後のdatasheet worst-case + STA + 実測 |
| `T-U003` | IRQ要求Low幅とtri-state線の安全なrelease手順 | positive edgeのみ確定 | PIC一次資料または代表機観測 |
| `T-U004` | 386以降のXA/XL/US/FA等の例外をどこまで保証するか | 386以降をtarget、古い世代はrecord-only、例外はnotesで保存 | `ws001p005`の対象機マトリクスをユーザ承認 |
| `T-U005` | 80286 12 MHzの内部capture方式 | SCLK基準禁止 | WS003 BFMで非同期strobes/dataを検証 |
| `T-U006` | S001外のPentium以降で後期型cycle familyから不連続な変更があるか | 現時点では同一familyのparameter差として扱う | 後続一次資料または実測でsignal/strobe/wait/IRQ差を照合 |

測定器がない現状では`T-U001`から`T-U003`を確定できない。これはPhase失敗ではなく、資料値と実機保証を混同しないための明示的境界である。
