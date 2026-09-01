# CバスFPGAボード Master Plan

最終更新: 2026-09-01

Status: approved, active

## 1. 目的

PC-9800シリーズのCバスへ接続し、ユーザがAXI4側へ独自ハードウェアIPを追加できるTang FPGAベースの汎用ボードを設計し、再現可能な形で頒布する。本書は戦略、スコープ、確定済みの主要設計判断の正本とする。

## 2. スコープ

初期製品のスコープ内:

- CバスのI/Oポートおよび必要なメモリサイクルをFPGAへ安全に接続する5 V対応フロントエンド
- Cバス・AXI4/AXI4-Liteブリッジと、タイムアウト、アクセス制御、CDC
- ボード上RISC-Vソフトコア、DRAM、システムCSR、メールボックス、割り込み
- AXI上のローカルDMA、PC-98の従来DMA、後期段階のCバス・バスマスタDMA
- AI生成を含むユーザIPを隔離して接続する安定したラッパ、SDK、サンプルIP
- SCSIエミュレーションやUSB連携へ発展できるサンプルとソフトウェア基盤
- Cバスユニバーサル基板による試作、専用PCB、製造試験、頒布資料

初期製品のスコープ外:

- 未検証のPC-9800機種・互換機・クロック条件への無条件な互換保証。ただし設計上はPC-9800シリーズ全般を互換目標とし、世代差を縮退構成と互換性マトリクスで扱う。
- Cバス信号へユーザ生成IPを直接接続すること
- 未検証の5 V直結FPGA採用による外付け保護・方向制御の省略
- 最初のRTL段階でSCSI、USBなど完成周辺機器をすべて実装すること
- Queue承認前の量産発注、販売、外部への公開

## 3. 最終ゴール

利用者が頒布物を入手し、公開された手順で安全にCバスへ装着し、基準bitstreamで動作確認できること。その後、安定したAXI4/AXI4-Lite境界へ独自IPまたはRISC-Vファームウェアを追加し、シミュレーションと実機テストを再現できること。

## 4. 現在の状況

- MWP-Q計画構造に加え、board非依存RTLとしてCバスI/O target engine、dual-clock CDC、AXI4-Lite Manager bridge、guard、共通IP topと自己検査BFMを実装した。Primer/Megaのdrive-disabled board wrapperとpin constraint fragmentも実装済みである。回路図、PCB、Gowin production wrapper、AXI interconnect、ファームウェアは未実装。
- CバスとFPGAの間にLVC系トランシーバを置く方針、AXI4を内部標準とする方針は合意済み。
- プロジェクトが試作・専用PCB・合成・実機検証・頒布する唯一のprimary board targetをTang Primer 20K SO-DIMMに固定した。Mega 138K非Proは共通IP/ABIのelaborationと論理互換性を保つreference targetとし、既存top・constraint・回帰資産は維持するが、Mega用Cバスcarrier/PCBは設計・製造対象にしない。
- 74LVC16245Aまたは74LVC162245Aは候補であり、電圧、方向、OE、電流、伝搬遅延、パッケージ、入手性の確認前には部品確定としない。
- Cバスの正式な信号集合、DMA調停、タイミング、機種差は一次資料と実機で検証が必要。
- 初期実機環境はPC-9821V13、x86ラボ`CB-U04`、Tang Primer 20Kである。Tang Nano 20Kは34 GPIOというI/O不足により製品platformから外し、Mega 138Kも製造ボード対象から外す。互換目標はV13固有ではなくPC-9800シリーズ全般であり、20-bit/24-bitアドレス、8/16-bitデータ、信号多重化などの世代差を明示して設計する。
- 現時点で専用測定器はなく、HDL検証には`iverilog`を利用できる。実測が必要な項目は未確認として分離する。
- RISC-Vコア設計は優先順位の再整理まで後回しとし、先行Workstreamのブロッカーにしない。
- `ws001p001`を完了し、Cバス系列資料とV13/Tang公式資料に基づく証拠台帳を作成した。現在はV13を初期実機候補に留め、PC-9800各世代の電気・電源・タイミングとスロット別多重信号を未確認IDで管理する。
- `ws001p002`でCバス全100端子と世代差を機械可読化した。AB00-AB23は8086型/286以降型の両方に存在するが、20-bit互換と24-bitフルデコードの扱いが異なる。
- Tang Nano 20Kの露出GPIOは34本である。独立したIORDY/IRQ OEを含めると8-bit I/O最小構成でも35本となり、1本不足する。この判断点はPrimer 20Kをprimary board targetに採用することで解消した。Nano直結は製品platformに含めない。
- Tang Primer 20K SO-DIMMとTang Mega 138K非Pro BTB SOMを多I/O候補として調査し、端子表、保守的GPIO数、コネクタ、給電条件を`ws002p001`の成果物へ記録した。
- 基本給電はCバス+5 Vを優先する。電力余裕が不足する構成ではPC-98内部FDD系5 Vからの補助給電コネクタを候補とし、Cバス電源との直結を避ける選択・逆流防止・保護回路を必須検討項目とする。
- `ws002p001`を完了した。Tang Primer 20Kは保守的に86本の3.3 V GPIOを持つ。`ws001p002`再開時に安全OEとDMA/bus-master同時予約を含む共通endpointを69本へ訂正し、Primerに17本の余裕があることを実mappingで確認した。公式Wikiの117 I/Oは回路図から再現できず、データシート103 User I/Oは端子分類と整合した。
- Tang Mega 138K非ProはBank 2/3/4から保守的に144 GPIOを使用でき、同じ69 endpoint mapping後も75本残ることを調査済みである。この資料はIP可搬性のreferenceとして保持するが、3個の0.4 mm BTBを使うMega carrierは本プロジェクトのPCB/製造範囲外とする。Tang Nano 20K直結は不採用、外部CPLD案は別アーキテクチャとして条件付きとする。
- NEC資料では初期機の+5 V上限が0.5 A/slot、後期機の多くが0.8 A/slotである。Primerの公式0.5 A要求は初期機上限と同値なので、PrimerキャリアにはCバス+5 V既定に加え、排他選択・逆流/過電流保護を持つキー付き補助5 V入力を設ける方針を推奨する。PC側FDD接続は機種別交換ハーネスへ分離する。
- `ws001p002`を完了した。共通`cbus_ip_top`用の69 endpointを、Primer SO-DIMMとMega BTBへ同じ順序で割り当てた。受動target、選択IRQ/DMA一経路、286以降型bus-master予約、安全DIR/OEを含み、Primerに17本、Megaに75本の保守的GPIOを残す。
- `ws001p003`を完了した。8086-classから486/Pentiumまでを9 timing profile、93 parameter、6 cycle contractへ整理した。80286 12 MHzではSCLKをtiming基準にできず、共通targetは非同期captureを前提にする。V13は資料の直接対象外なので実測前には486/Pentium profileを互換保証に使わない。
- 初期の設計・互換性試験・保証対象は386以降とする。8086/70116/80286固有差は記録のみ保持する。S001上では486/Pentiumも同じ後期型signal/cycle familyであり、parameter差として扱う。後続資料または実測でprotocol上の不連続が判明した場合は再検討する。
- Queue完了時または切りのよい境界で、成果をcommitして`git push origin master`することがユーザから許可されている。
- `ws003p001`を完了した。100 MHz内部clockで非同期I/O strobeを同期化し、一件の`cbus_req/cbus_rsp`へ変換するtarget MVPとID/version/scratch/status CSRを実装した。Icarus Verilog 12.0で8/16-bit lane、wait/timeout、無効/非選択、reset/platform abort、contention/Xを157 checks検証した。
- `ws003p002`を完了した。Gray pointerのdual-clock request/response FIFO、8-bit tagによる遅延response隔離、32-bit AXI4-Lite Manager bridgeをboard非依存subsystemへ統合した。異なる10 ns/14 ns clock、AXI channel別backpressure、byte lane、SLVERR、timeout後の復旧を含む合計467 checksを検証した。
- `ws003p003`を完了した。System CSR regionだけを許可するAXI4-Lite guard、local DECERR、bounded timeout、全timeoutのquarantine、下流reset要求、first-fault recordを実装した。host aperture禁止、VALID保持、部分write、遅延response drain、Cバス統合復旧を含む合計635 checksを検証した。
- `ws002p002`を完了した。flat-port `cbus_ip_top`、六条件の組合せ安全gate、共通board shell、Primer/Mega top、各69 endpoint＋clockのCSTを実装した。新規3355 checksと既存635 checks、構造・pin validatorをPASSした。board topの既定buildはdrive-disabledであり、Gowin clock/config status wrapper、外付けOE pull-up/安全latch、合成、実機High-Zは未検証のまま次Phaseへ残した。
- `ws003p006`を完了した。共通IP内に四wordのAXI4-Lite System CSRを統合し、ID/version/capability、byte-strobe scratch、Cバス/guard status summaryを実装した。Primer/Mega topのCバス8-byte窓から同じCSRを読書きでき、現在のHDL回帰4033 checksをPASSした。guard fault clearは遮断済みCバス経路へ置かず、独立管理経路の後続課題とした。
- `ws005p001`を完了した。H2C/C2Hを各8-entry×32-bit FIFO、doorbellを1-bit coalescing pending、interruptをCPU/host別mask/W1CとするABI v1を固定した。31 register、17 event、16のCバス相対aliasをJSONからSV/C/Rustへ生成し、24 contract checksをPASSした。物理IRQ番号、I/O base、RISC-Vは未決定のままである。
- `ws005p002`を完了した。同期FIFO core、独立AXI4-Lite mailbox/router、二つのsubordinate portを接続するboard-independent subsystemを実装した。FIFO境界表25 checksと31 register、event routing、W1C/mask/set-wins、doorbell coalescing、AXI backpressure/error/resetの91 checksをPASSし、既存HDL 4033 checksとABI 24 checksに回帰がない。共通IP/AXI fabric/Cバスalias統合は後続`ws005p005`に残す。
- 初回ユニバーサル基板試作用として、ユーザがx86ラボ`CB-U04`を購入した。入手後に表裏パターン、カードエッジ処理、+5 V/GND引出し、Cバス端子からlandへの導通を確認する。

## 5. 固定済みの主要設計判断

- 論理インターフェースはCバス信号名を一対一で表し、物理トップで外付けLVCの `DIR` と `OE` を制御する。
- FPGA側の内部バスは32-bit AXI4 Fullと32-bit AXI4-Liteを基準とする。Cバスの8/16-bit転送はブリッジで変換する。
- リセット、コンフィグ、クロック未確立、バス非所有時にはCバス向け出力をHigh-Zとする。
- Cバス受動ターゲットと能動バスマスタを別エンジンに分離する。
- CバスとAXIのクロック領域は分離し、要求・応答FIFOでCDCする。実際のサンプリング方式はタイミング根拠により確定する。
- Cバス16-bit wordは32-bit AXI4-Lite registerへword単位で展開し、Cバスoffset `+0/+2/+4/+6`をAXI offset `+0/+4/+8/+12`へ変換する。8-bit tagでtimeout後の遅延responseを隔離する。
- Cバス由来AXI4-Lite Managerは既定でSystem CSR `0x1000_0000-0x1000_0fff`だけを許可し、PC-98 host apertureをlocal DECERRにする。AXI timeout後はVALID handshakeの有無にかかわらず下流をquarantineし、subordinate reset後の明示的fault clearまで再利用しない。
- ユーザIPは生のCバスへ接続せず、AXI-Lite、IRQ、DMA要求、必要に応じAXI-Streamまたは保護されたAXI Managerを使用する。
- Cバスから入ったAXI要求がPC-98ホスト窓へ再入する経路は禁止し、再帰デッドロックを防ぐ。
- 初期のCPUキャッシュは無効、またはDMA共有領域を非キャッシュとし、整合性問題を後段へ持ち越さない。
- Primer 20Kをprimary hardware targetとし、Mega 138Kは共通IPのreference targetに限定する。Cバス/AXI/CSR/mailbox/DMA/user IP/将来RISC-Vはboard名を持たない共通`cbus_ip_top`以下へ置き、共通IP内にPrimer/Megaの条件コンパイルを持ち込まない。Mega reference topのelaboration/ABI回帰は維持するが、Mega用回路図・PCB・PCBA・実機保証は作成しない。
- board topは共通IPのOE requestをplatform ready、reset、clock lock、bus permitで追加gateし、configuration中は外付けpull-up等によりRTL非依存でLVCをHigh-Zにする。
- 初期Cバス互換profileは386以降を対象とする。8086/70116/80286固有profileは調査記録として保持し、初期対応を強制しない。Pentium以降に後期型cycle familyとの不連続が見つかった場合はtarget engineの境界を再検討する。

## 6. 提案中の論理構成

```text
Primer 20K primary board top       Mega 138K reference top
  product pins/CST/PLL/DDR/OE        elaboration/ABI portability only
                     \              /
                      +-- cbus_ip_top --+
                    |
C-bus connector <-> LVC <-> cbus_pad_adapter
                    <-> cbus_target_engine -> CDC -> AXI-Lite guard -> fabric
                    <-> cbus_master_engine <- axi_to_cbus_bridge <- host apertures
                    <-> legacy_8237_dma_engine

AXI4 fabric
  managers: RISC-V CPU, DMA, C-bus target bridge
  targets : DRAM, protected PC-98 apertures, AXI4-Lite bridge

AXI4-Lite
  system CSR, DMA CSR, interrupt router, mailbox, user IP region
```

モジュール名と境界はP書で検証後に確定する。特定ベンダIPは `rtl/vendor/gowin/` 相当のラッパ内へ隔離する。

## 7. 提案中のAXIアドレスマップ

| 範囲 | 用途 | 備考 |
| --- | --- | --- |
| `0x0000_0000-0x00FF_FFFF` | FPGAローカルDRAM | 初期16 MiB窓、実容量確認後に調整 |
| `0x1000_0000-0x1000_0FFF` | System CSR | ID、版数、状態、障害 |
| `0x1000_1000-0x1000_1FFF` | DMA CSR | 記述子、状態、エラー |
| `0x1000_2000-0x1000_2FFF` | Interrupt router | pending、mask、ack |
| `0x1000_3000-0x1000_3FFF` | Mailbox | H2C/C2H FIFO、doorbell |
| `0x2000_0000-0x2FFF_FFFF` | User IP | AXI-Liteを基本とする |
| `0x8000_0000-0x80FF_FFFF` | PC-98 memory aperture | AXIからのCバス・マスタ転送 |
| `0x8100_0000-0x8100_FFFF` | PC-98 I/O aperture | AXIからのCバス・マスタ転送 |

これは予約案であり、CPUブート構成、実DRAM容量、Cバスアドレス幅の確認後に凍結する。

## 8. DMAモデル

1. AXIローカルDMA: DRAM、FIFO、ユーザIP間をコピーする。
2. 従来DMA: `DRQ/DACK/TC/WORD` 等を使い、PC-98側DMACがアドレスとカウントを管理する。
3. Cバス・バスマスタDMA: FPGAがバス権を得てPC-98メモリ/I/Oへアクセスする。互換性と電気的リスクが高いため後期Phaseとする。

すべてMMIO CSRから制御でき、完了・エラーを割り込みへ通知する。各モードのチャネル、信号名、最大バースト、境界条件は仕様調査後に確定する。

## 9. 通知モデル

通常の公開レジスタ書込みすべてを割り込み化しない。PC-98からメールボックスへデータを書いた後、H2C doorbell書込みでRISC-VへIRQを発生させる。逆方向はC2H doorbellから選択したCバスIRQを発生させる。pendingはW1C、maskを別レジスタとする。必要なら後期Phaseで監視書込みFIFOを追加する。

## 10. Milestone Goals

| ID | 観測可能な到達状態 |
| --- | --- |
| `MG001` | Cバス一次資料、実機観測、Tang/LVCデータシートに基づく信号・電気・タイミング・I/O予算がレビュー済みである。 |
| `MG002` | ユニバーサル基板試作で、安全なHigh-ZとCバスI/OポートからのID/CSR読書きを複数回再現できる。 |
| `MG003` | RISC-V、DRAM、AXI4、メールボックス、割り込みが統合され、PC-98とボードCPU間の双方向コマンドが動作する。 |
| `MG004` | AXIローカルDMAと従来DMAが検証され、必要な対象機ではCバス・バスマスタDMAも安全に動作する。 |
| `MG005` | ユーザIPラッパ、SDK、サンプルIP、RISC-Vファームウェア例から第三者が拡張bitstreamを再現できる。 |
| `MG006` | 専用PCBの試作・製造試験・互換性試験・BOM・組立・安全手順が揃い、小規模頒布判定を通過する。 |

## 11. Workstream registry

| WSID | Workstream | Status | Milestones | Resume point | W書 |
| --- | --- | --- | --- | --- | --- |
| `ws001` | Cバス仕様・インターフェース契約 | in-progress (p003 completed) | MG001 | 次はp004 DMA/bus-master契約、または測定器準備後のp005実機互換性 | [WS001](ws001-cbus-contract/ws.md) |
| `ws002` | FPGA・電気・安全プラットフォーム | in-progress (p002 completed) | MG001, MG002 | 次はGowin production wrapperと外付け安全回路を具体化し、測定環境準備後にp003立上げ | [WS002](ws002-fpga-platform/ws.md) |
| `ws003` | Cバス・ターゲット/AXIブリッジ | in-progress (p006 completed) | MG002 | System CSRは完了。p004はメモリcycle根拠後、p005は試作hardware後 | [WS003](ws003-target-bridge/ws.md) |
| `ws004` | AXI SoC・RISC-V・DRAMランタイム | planning (deferred) | MG003 | 優先順位と実行順を再整理してからCPU/ブート/DDR構成を選定する | [WS004](ws004-soc-runtime/ws.md) |
| `ws005` | メールボックス・割り込み | in-progress (p002 completed) | MG003 | 次はp005の共通IP/AXI fabric/Cバスalias統合を実行可能なP書へ詳細化 | [WS005](ws005-mailbox-interrupt/ws.md) |
| `ws006` | DMA・Cバスバスマスタ | planning | MG004 | DMAモード別の信号・安全条件を確定する | [WS006](ws006-dma-bus-master/ws.md) |
| `ws007` | ユーザIP SDK・サンプル | proposed | MG005 | 基盤APIが安定後に詳細化する | [WS007](ws007-user-ip-sdk/ws.md) |
| `ws008` | 専用PCB・製造・頒布 | proposed | MG002, MG006 | 入手後のCB-U04を調査し、ユニバーサル基板試作の結果を反映する | [WS008](ws008-production-board/ws.md) |

## 12. 依存関係

```text
WS001 bus contract
  +-- WS002 electrical/platform safety
  |     +-- WS003 target bridge MVP
  |     |     +-- WS005 mailbox/interrupt
  |     |     +-- WS004 SoC/runtime
  |     |           +-- WS006 DMA/bus master
  |     |           +-- WS007 user IP SDK
  |     +-- WS008 universal prototype -> production PCB
  +-- WS006 legacy DMA and bus-master protocol evidence

Verification evidence is produced inside every Workstream and is consumed by WS008.
```

## 13. 未解決の人間判断

次の事項は判断材料を各W/P書で揃えた後、Queue投入前にユーザが決める。

- Primer 20Kモジュールの購入版、SO-DIMM socket/実装高さ、初回製造数、量産時の供給方針
- 最初に保証対象とするPC-9800機種、CPU速度、Cバス条件
- 初版PCBでバスマスタDMA用の双方向アドレス/制御配線を実装するか
- CバスI/Oベースアドレス、IRQ、DRQ/DACKの設定方式と競合回避方式
- SCSI、USBその他のうち、頒布時の代表サンプルに含める機能
- 基板サイズ、部品実装範囲、目標原価、頒布数、認証・表示・サポート範囲

## 14. 横断的な受入原則

- バスへ出力する前に、シミュレーションで方向競合とリセット時High-Zを検証する。
- AXI応答、Cバスwait、タイムアウト、エラーは無限待ちにならず観測可能である。
- 8/16-bit、奇偶バイトレーン、未整列、境界、リセット中断をテストする。
- 実機試験は電流制限、ロジックアナライザ、段階的信号有効化を用い、試験機とFPGAを保護する。
- 完了判定は変更量ではなく、P書に記録したコマンド、波形、測定値、対象機、版数などの証拠に基づく。
