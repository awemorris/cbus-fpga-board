# Cバスrequest/response CDC・AXI4-Lite契約

最終更新: 2026-09-01

対象Phase: [`ws003p002`](phase002-cdc-axil-bridge/phase.md)

## 1. 境界

`cbus_target_axil_subsystem`は、I/O/memory engineが生成するspace付き24-bit requestをCバス側clock domainからAXI側clock domainへ搬送し、32-bit AXI4-Lite Manager transactionへ変換する。Primer/Megaのpin、PLL、DDR、Gowin primitiveには依存しない。

## 2. Clockとreset

- `c_clk`: Cバスcycle検出、IORDY、data OE、Cバス側FIFO portを動かす。
- `a_clk`: AXI4-Lite bridgeとAXI側FIFO portを動かす。
- 二つのclock間に周波数または位相関係を要求しない。
- 外部`rst_n`は両domainへ非同期assertし、`reset_sync`で各clockへ2段同期してdeassertする。
- request FIFO、response FIFO、AXI subordinateを含む経路は同じsystem resetでcoherentにresetする。片側domainだけのresetや、受理済みAXI transactionをsubordinate側へ残したままManagerだけresetする操作は許可しない。
- `platform_ready`はCバスOEと新規Cバスrequestを即時gateする。すでにAXIへ受理されたwriteの取消しは保証しない。

## 3. CDC packet

既定FIFOはdepth 4、Gray code pointer、2段pointer synchronizerを使う。payloadをbit単位で同期せず、write pointerが同期先へ到達した後にread側dual-port memoryから読む。

Request packet:

| Field | Width | Meaning |
| --- | ---: | --- |
| `tag` | 8 | Cバス側でrequest受理ごとに増加する識別子 |
| `space_memory` | 1 | 1=24-bit memory、0=16-bit I/O |
| `write` | 1 | 1=write、0=read |
| `addr` | 24 | `AB00`を含むCバスaddress。I/Oでは上位8 bit zero |
| `wdata` | 16 | Cバスwrite data |
| `be` | 2 | `{upper,lower}` byte enable |

Response packet:

| Field | Width | Meaning |
| --- | ---: | --- |
| `tag` | 8 | 対応requestのtag |
| `error` | 1 | AXI errorまたはbridge decode error |
| `rdata` | 16 | read data。writeでは未使用 |

Cバス側endpointはresponse FIFOを常にdrainする。response tagが現在のactive tagと一致するときだけtarget engineへ`rsp_valid`を渡し、不一致は`stale_rsp_pulse`を1 cycle出して破棄する。これにより、Cバスtimeout後に遅れて完了したAXI responseを後続cycleへ誤適用しない。

同時に保持できる未処理requestはFIFO depthとAXI bridge内の一件に制限される。8-bit tagがwrapする前に最大保持数へ達するため、通常運用で同時に存在するtagは一意である。

## 4. Address・lane変換

既定値:

- CバスI/O base: `0x00d0`（実機資源選定前の仮値）
- AXI4-Lite base: `0x1000_0000`（Master PlanのSystem CSR予約領域）

各Cバス16-bit wordを一つの32-bit AXI registerへ展開する。

| Cバスaddress | AXI address | AXI data/strobe |
| --- | --- | --- |
| `base+0` / `base+1` | `AXIL_BASE+0x0` | `RDATA[15:0]` / `WDATA[15:0]`、`WSTRB[1:0]=be` |
| `base+2` / `base+3` | `AXIL_BASE+0x4` | 同上 |
| `base+4` / `base+5` | `AXIL_BASE+0x8` | 同上 |
| `base+6` / `base+7` | `AXIL_BASE+0xc` | 同上 |

変換式は `AXIL_BASE + (((cbus_addr & 0xfffe) - CBUS_BASE) << 1)` である。16-bit accessは`WSTRB=0011`、low byteは`0001`、odd-address high byteは`0010`とする。AXI data upper 16 bitはzeroで、readはlower 16 bitをCバスへ返す。

memory spaceは自然なbyte addressを維持し、`AXIL_MEM_TARGET_BASE + ((cbus_addr & 0xfffffc) - (CBUS_MEM_BASE & 0xfffffc))`へ変換する。Cバスaddress bit 1が0ならAXI lower halfと`WSTRB[1:0]`、1ならupper halfと`WSTRB[3:2]`を使う。`CBUS_MEM_ENABLE=0`が既定で、Cバスbase/maskとAXI target baseは実機割当前のplaceholderである。

## 5. AXI4-Lite sequencing

- 一度に一transactionだけを発行する。
- Write addressとwrite dataは独立channelとしてvalidを保持し、それぞれのready handshakeを別々に記録する。
- 両方のhandshake後にB responseを待つ。
- ReadはAR handshake後にR responseを待つ。
- `BRESP/RRESP=OKAY`以外は`rsp_error=1`へ変換する。
- response FIFOが満杯ならbridgeはresultを保持し、AXI responseを失わない。
- `AWPROT/ARPROT`はdata、secure、unprivilegedを表す`000`で固定する。

AXI subordinateが永久に応答しない場合もCバス側は既存timeoutでIORDYを解放する。ただしassert済みAXI transaction自体はAXI4-Lite上で取消せない。`ws003p003`の[AXI4-Lite guard契約](axil-guard-contract.md)ではCバスtimeoutより短いguard timeout、quarantine、下流reset要求、明示的fault clearを追加する。

## 6. Safety invariants

- CDC backpressure時もrequest/response payloadを保持する。
- response tag不一致をCバスへ返さない。
- resetまたは`platform_ready=0`でCバスdata OEとIORDY OEを出さない。
- AXI backpressure中にvalid、address、data、strobeを変更しない。
- Cバス由来のAXI address範囲制限は後段のregion guardでも実施する。今回のbridgeだけを無制限なAXI fabricへ直結しない。
