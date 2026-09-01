# ws004p002: AXI4/AXI4-Lite SoC interconnect

最終更新: 2026-09-01

WSID: `ws004`

Phase ID: `p002`

Combined ID: `ws004p002`

Status: planned; ready for Queue proposal

Parent: [WS004](../ws.md)

## User decision

SoCにはユーザIPを接続する固定slotとして、AXI4 Full subordinateを1本、AXI4-Lite subordinateを1本用意する。各slotは独立したcompile-time parameterで無効化でき、無効buildではuser側datapathをgenerateで作らず、外向きrequestをinactiveに固定する。予約addressへのaccessにはfabric内のerror targetが`DECERR`を返すため、CPUを無限waitさせない。

parameter定数によってuser target本体と外向きfan-outは合成除去可能にする。ただし、予約addressへ決定的に`DECERR`を返すための最小decode/error pathは残してよい。実際のGowin netlistでの除去確認はIP-complete gate後の合成Phaseで行う。

## Objective

`ws004p001`の単一32-bit CPU AXI4 Managerを、reference memory、CPU/Cバス共有control plane、将来の保護付きPC-98 aperture、およびFull/Lite各1本のユーザIP target slotへ安全に接続する。decode、protocol制限、2-manager AXI4-Lite arbitration、timeout/error isolationをboard/vendor非依存RTLとして実装し、`ws004p004`のCPU/ROM/BRAM起動と`ws005p004`のevent FIFO CSRを接続できる状態にする。

## Entry conditions

- `ws004p001`のCPU AXI4/IRQ ABI v1.0が完成している。
- `ws003p004`のCバスI/O/memory共通requestとguard経路が完成している。
- `ws005p005`のSystem CSR、interrupt router、mailbox、1-manager control decodeが完成している。
- CPU Managerはread/write各1 outstanding、32-bit data、2-bit ID、`INCR` burstだけを必須とする。

## Fixed topology

```text
user RISC-V core / CPU BFM
        |
        | 32-bit AXI4, ID width 2
        v
  CPU AXI4 target router
    +-- 0x0000_0000..00ff_ffff -> reference memory target
    +-- 0x1000_0000..1000_ffff -> single-beat AXI4-to-AXI4-Lite adapter
    +-- 0x2000_0000..27ff_ffff -> user AXI4 Full target slot
    +-- 0x2800_0000..2800_ffff -> same AXI4-to-Lite adapter -> user Lite
    +-- 0x8000_0000..80ff_ffff -> protected PC-98 memory aperture slot
    +-- 0x8100_0000..8100_ffff -> protected PC-98 I/O aperture slot
    +-- otherwise              -> local DECERR target

 CPU AXI4-to-Lite ----+
                      +--> 2-manager AXI4-Lite arbiter --> policy/decode
 guarded C-bus AXIL --+       +-- System CSR
                              +-- DMA CSR reservation
                              +-- interrupt router
                              +-- mailbox
                              +-- C-bus write-event CSR reservation
                              +-- user AXI4-Lite target slot
                              +-- local DECERR target
```

CPU Full routingと共有Lite control planeを分離する。Cバス由来transactionはAXI4-Lite arbiterへだけ入り、reference memory、user Full、PC-98 apertureへ到達する経路を持たない。将来のDMA/Cバスbus-master Manager追加はWS006で行い、本Phaseで未使用の複数Manager portを広く配線しない。

## Address map contract

| Range | Target | Initial access | Disabled/unimplemented behavior |
| --- | --- | --- | --- |
| `0x0000_0000-0x00FF_FFFF` | reference memory/後段DDR target | CPU AXI4 | p002 BFM memoryへ接続。target absentなら`DECERR`。 |
| `0x1000_0000-0x1000_0FFF` | System CSR | CPU + guarded Cバス | 既存実装へ接続。 |
| `0x1000_1000-0x1000_1FFF` | DMA CSR reservation | CPU | WS006まで`DECERR`。Cバスは禁止。 |
| `0x1000_2000-0x1000_2FFF` | Interrupt router | CPU +既存Cバスalias | 既存実装へ接続。 |
| `0x1000_3000-0x1000_3FFF` | Mailbox | CPU +既存Cバスalias | 既存実装へ接続。 |
| `0x1000_4000-0x1000_4FFF` | Cバスwrite-event CSR reservation | CPU | `ws005p004`まで`DECERR`。Cバスaliasなし。 |
| `0x1000_5000-0x1000_FFFF` | platform control reservation | CPU | software interrupt/timer等の割当前は`DECERR`。 |
| `0x2000_0000-0x27FF_FFFF` | user AXI4 Full target slot 0 | CPU、将来policy付きDMA | `USER_AXI_FULL_ENABLE=0`でlocal `DECERR`。 |
| `0x2800_0000-0x2800_FFFF` | user AXI4-Lite target slot 0 | CPU | `USER_AXIL_ENABLE=0`でlocal `DECERR`。Cバスは禁止。 |
| `0x2801_0000-0x2FFF_FFFF` | user expansion reservation | none | `DECERR`。 |
| `0x8000_0000-0x80FF_FFFF` | PC-98 memory aperture | CPU、将来policy付きDMA | WS006のbridge接続前は`DECERR`。Cバスは禁止。 |
| `0x8100_0000-0x8100_FFFF` | PC-98 I/O aperture | CPU、将来policy付きDMA | WS006のbridge接続前は`DECERR`。Cバスは禁止。 |
| その他 | unmapped | none | `DECERR`。 |

このPhaseで上表をboard-independent ABIとして固定する。物理DRAM容量、Cバス側の実resource割当、user IP内部register mapは固定しない。user Full/Lite windowのbase/size変更はdecoderだけでなくSDK ABIへ影響するため、実装後はPhase追加または明示的ABI revisionとして扱う。

## CPU AXI4 routing contract

- CPU側は`AXI_ADDR_WIDTH=32`、`AXI_DATA_WIDTH=32`、`AXI_ID_WIDTH=2`とし、p001の全channelをそのまま受ける。
- routerはread/write各1 transactionを保持する。read routeは`AR`から最終`RVALID && RREADY && RLAST`まで、write routeは`AW`から`BVALID && BREADY`まで固定する。
- `W`は対応する`AW`を受理するまでtargetへ渡さない。`AW`と`W`の独立handshakeを正しく扱い、payloadはbackpressure中に保持する。
- reference memory、user Full、PC-98 apertureは`INCR` burstを許可する。burst全体が同じdecode window内かつ4 KiB boundary内であることを最初に検査する。
- `FIXED/WRAP`、4 KiB crossing、不正`SIZE`、window crossingはtargetへ出さず`DECERR`にする。拒否writeは宣言されたbeatまたは`WLAST`まで安全にdrainしてから一件の`B` responseを返す。
- downstreamの`BID/RID`を検査し、CPUへは受理した`AWID/ARID`を対応responseとして返す。`RLAST`の早過ぎ/遅過ぎもprotocol faultとして隔離する。
- readとwriteは独立に進められるが、同一方向で二件目を受理しない。p001を超えるmultiple outstanding最適化は本Phaseに含めない。

## AXI4-to-AXI4-Lite adapter contract

- control/MMIO accessは`LEN=0`、`WLAST=1`、1/2/4-byte beat、addressと`WSTRB`の整合を必須とする。
- unsupported burst、misaligned access、不正lane、instruction fetchとしてのMMIO accessはAXI4-Liteへ出さずlocal `DECERR`にする。
- `AW`と`W`を個別にbufferし、両方が揃ってから一件のAXI4-Lite writeとして発行する。read/write各1 outstandingとする。
- AXI4-Liteの`BRESP/RRESP`をCPU AXI4へ伝え、`BID/RID`は受理したCPU ID、single readの`RLAST`は1とする。
- reset中は全request/response handshake outputをinactiveにし、coherent SoC resetで未完transactionを破棄する。

## Shared AXI4-Lite arbitration and access policy

- Manager 0はCPU adapter、Manager 1は既存Cバスguard出力とする。
- read/writeを独立したtransaction単位round-robinで調停し、response完了までownerを変えない。一方がidleなら他方へ追加cycleを与える。
- CPUとCバスの同時access、`AR`と`AW/W`の同時進行、全response channelのbackpressureを許容する。
- CバスManagerは既存guard/aliasが許可するSystem CSR、interrupt router、mailboxだけに限定する。DMA、event FIFO、user Lite、host apertureへの直接routeを追加しない。
- CPUは上表のCPU許可領域へaccessできる。未実装予約ページは明示的`DECERR`とし、別targetへaliasしない。
- arbiter待ち時間とdownstream timeoutの上限は既存Cバスguard timeoutより短く設定できるparameter関係をvalidatorで確認し、CPU側の故障targetがCバスを無期限に占有しないようにする。

## User target slots

### AXI4 Full slot 0

- 32-bit AXI4 subordinate-facing bundle、2-bit IDを公開し、CPU側の合法`INCR` burst、byte lane、ID、responseを保持する。
- `USER_AXI_FULL_ENABLE=1`のbuildだけでtarget-facing datapathとtimeout wrapperをgenerateする。
- `USER_AXI_FULL_ENABLE=0`ではtarget-facing `AWVALID/WVALID/ARVALID/BREADY/RREADY`を0に固定し、全payloadを0または既知定数にする。user入力に依存せず選択accessへlocal `DECERR`を返す。
- user Full slotは「CPU/DMAからaccessされるTarget」である。user IPがDRAMやhost apertureへ要求を出すAXI Manager権限とは別契約であり、後者はWS007/WS006のfirewall判断なしに付与しない。

### AXI4-Lite slot 0

- 32-bit AXI4-Lite subordinate-facing bundleを共有control planeの一Targetとして公開する。
- `USER_AXIL_ENABLE=1`のbuildだけでslotをdecodeし、CPU accessを渡す。初期policyではCバスManagerを常に拒否する。
- `USER_AXIL_ENABLE=0`ではtarget-facing requestをinactive、response-readyを0、payloadを既知定数にし、選択accessへlocal `DECERR`を返す。
- slot内部のregister map、IRQ、DMA request、CDC wrapperはWS007が定義する。本Phaseはbus、address、error、reset境界だけを固定する。

二つのslotはboard pinへ展開しない。共通SoC/interconnect内部の安定portとして置き、`cbus_ip_top`統合時はsafe terminationまたは後段`user_region_wrapper`へ接続する。したがってPrimer/Mega board top、69 endpoint、CSTは変更しない。

## Guard, timeout, and fault behavior

- decode miss、disabled slot、manager policy違反、protocol subset違反は`DECERR`を返す。
- downstreamが明示した`SLVERR/DECERR`は意味を変えずupstreamへ返す。
- targetがparameter化された上限内に応答しない場合は当該upstream transactionへ`SLVERR`を返し、sticky faultを立てる。
- timeoutしたtargetは遅延responseが新しいtransactionへ誤対応しないようquarantineする。coherent target resetと明示fault clear、またはSoC resetまで再利用しない。
- user Full、user Lite、host apertureを個別に隔離し、一つのoptional target故障で無関係なSystem CSR/mailbox accessを永久停止させない。
- first-fault情報としてmanager、target、read/write、address、ID、原因を内部statusに保持し、最低限のsummaryをSystem CSR diagnosticへ接続する。register割当変更が必要なら既存ABI生成規則に従い、黙って既存fieldを再利用しない。
- timeout途中のAXI writeはdownstream side effectの有無を取り消せない。fault後の再試行はsoftware policyとし、fabricが自動再発行しない。

## Expected implementation boundary

module名は実装時の依存調査で最終確定するが、責務は次へ分離する。

- CPU AXI4 target router/error target。
- single-beat AXI4-to-AXI4-Lite adapter。
- 2-manager AXI4-Lite transaction arbiterとper-manager policy。
- 既存`axil_control_fabric_1x3`を置換または後方互換wrapper化する拡張decoder。
- per-target timeout/quarantineとfault summary。
- board-independent SoC integration shell、behavioral memory、enabled/disabled user target BFM。

既存`cbus_control_subsystem`と`cbus_ip_top`のsafe-default動作を維持する。大規模な単一moduleへCPU router、Lite arbitration、peripheral本体を混在させない。

## Work packages

- [ ] address mapとCPU/Cバス/user slot access matrixをmachine-checkable contractへする。
- [ ] CPU AXI4 router、local error response、burst/window validationを実装する。
- [ ] single-beat AXI4-to-AXI4-Lite adapterを実装する。
- [ ] CPU/Cバスの2-manager AXI4-Lite arbitrationとpolicy decodeを実装する。
- [ ] 既存System CSR、interrupt router、mailboxを共有control planeへ移行する。
- [ ] DMA CSR、event CSR、platform reservationをaliasなし`DECERR` targetとして確保する。
- [ ] Full/Lite user target slot、compile-time disable、safe terminationを実装する。
- [ ] reference memory BFMと将来host aperture用error/timeout境界を接続する。
- [ ] fault/timeout/quarantineを実装し、System CSR diagnosticへsummaryを渡す。
- [ ] 単体・競合・統合BFM、address-map/port validator、既存全回帰を実行する。
- [ ] M/W/P/Qへ実行結果、未解決事項、再現コマンドを同期する。

## Verification plan

- reference memoryでsingle/burst read/write、1/2/4-byte lane、ID、`LAST`、backpressure、read/write同時進行を検査する。
- System CSR、interrupt router、mailboxをCPUからread/writeし、既存Cバスaliasの結果が移行前と一致することを検査する。
- CPU/Cバスが同じ/異なるLite targetへ同時accessした場合のowner固定、round-robin、response routing、starvationなしを検査する。
- MMIO burst、misalignment、4 KiB/window crossing、illegal burst、bad `WLAST/RLAST`、unmapped accessへ有限時間で正しいerrorを返す。
- `0x1000_4000`が`ws005p004`未接続時はCPUへ`DECERR`、接続BFM時はCPU AXI4から到達し、Cバスからは到達しないことを検査する。
- user Full/Liteを各々enable/disableした4構成でelaborateし、enabled targetのdata/error/backpressureとdisabled時のinert output/local `DECERR`を検査する。
- CバスからDMA/event/user Lite/host apertureへ到達できず、CPUからCバスoriginへ再帰する経路がないことを検査する。
- target timeout、遅延response、quarantine、fault clear/reset、別target継続動作を検査する。
- parameter不正、address overlap、timeout上限逆転、port幅不一致をvalidator/elaboration assertionで拒否する。
- SystemVerilog 2012、Icarus Verilog 12.0、`-Wall -Wimplicit`で新規BFMと既存WS002/WS003/WS004/WS005、ABI/validatorをwarningなしでPASSさせる。

## Completion conditions

- CPU BFMが同一AXI4 Managerからreference memoryと既存AXI4-Lite peripheralへaccessできる。
- CPUとCバスがSystem CSR/interrupt/mailbox control planeを共有してもresponse混線、starvation、永久waitがない。
- `0x1000_4000`のCPU routeが予約済みで、`ws005p004`はdecoder再設計なしにevent FIFO CSRを接続できる。
- Full 1本、Lite 1本のuser target slotが固定address/port contractを持ち、enabled BFMで動作し、disabled buildで外向き信号がinactiveかつaccessが有限時間の`DECERR`になる。
- illegal、unmapped、timeout、downstream errorが区別され、fault後も無関係targetを利用できる。
- Primer/Mega pin、CST、Gowin primitive、物理DDRなしで再現可能なboard-independent回帰がPASSする。

## Excluded

- user RISC-V core内部、CPU boot、BSP、firmware。これらは`ws004p004`。
- event FIFO本体とIRQ bit 7統合。これは`ws005p004`。
- user IP wrapper、register generator、IRQ/DMA API、sample IP。これはWS007。
- user IPのAXI Manager権限、DMA Manager、Cバスbus-master engine。これはWS006/WS007で別途policyを固定する。
- Gowin DDR controller、PLL、physical board wrapper、合成/P&R、実機。
- cache coherency、exclusive/atomic、複数CPU、複数outstanding最適化。

## Interruption and resume policy

- user coreがread/write各1を超えるoutstanding、`WRAP/FIXED`、exclusive/atomic、64-bit dataを必須とする場合は実装前にp001 ABIとrouter規模をユーザ判断へ戻す。
- Full/Lite user windowのbase/sizeまたはCバスからuser Liteへのaccessが必要になった場合は、firewallとSDK ABIへの影響を提示し、暗黙に許可しない。
- target timeout後に安全なquarantineを構成できない場合はerror応答を捏造して続行せず、target reset/隔離契約を別Phaseへ戻す。
- optional slotのgenerate除去がGowin合成で成立しない場合はnetlist/resource差分を示し、decoder維持かwrapper変更かをIP-complete gateで判断する。

## Queue boundary

本書は設計・実装計画であり、現時点の`plan/queue.md`を置き換えず実行許可を与えない。実装開始時は`ws004p002`だけを有限のQueueとして提示し、ユーザ承認後にRTL、test、integrationを変更する。
