# `cbus_req/cbus_rsp` MVP契約

最終更新: 2026-09-01

対象Phase: [`ws003p001`](phase001-bfm-target-mvp/phase.md)、[`ws003p004`](phase004-memory-target-rtl/phase.md)

## 1. 境界

`cbus_target_engine`と`cbus_memory_target_engine`は、非同期なCバスI/O/memory cycleを内部clock domainの一件の共通requestへ正規化する。I/O engineの既存16-bit portは維持し、共有arbiterで`space=I/O`と上位zeroの24-bit addressへ拡張する。memory engineは`SALE`で保持した上位7 bitとcycle開始時の`AB[16:0]`を結合する。Primer/Megaのpin、PLL、LVC primitiveを参照しない。

## 2. Request

| Signal | Meaning |
| --- | --- |
| `req_valid` | request fieldsが有効。`req_ready`と同時Highのclock edgeで受理される。 |
| `req_ready` | backendがrequestを受理可能。 |
| `req_space_memory` | 1=24-bit memory、0=16-bit I/O。CDC packet以降で明示する。 |
| `req_write` | 選択spaceに対して1=write、0=read。 |
| `req_addr[23:0]` | `AB00`をbit 0に保持する。I/Oは`{8'h00, io_addr}`、memoryはSALE保持値を含む24-bit address。 |
| `req_wdata[15:0]` | write cycleでcaptureしたDB。 |
| `req_be[1:0]` | `{upper,lower}`。`upper=~BHE0`、`lower=~AB00`。`00`は不正。 |

`req_valid`は受理まで保持する。一つのCバスcycleにつき最大一requestとし、outstandingは一件に限定する。I/Oとmemory strobeが重なる場合は両engineを電気的にsilentにしてrequestを発行せず、sticky invalidを残す。arbiterはwire-ORせず、競合しない一方だけをCDCへ渡す。

## 3. Response

| Signal | Meaning |
| --- | --- |
| `rsp_valid` | 当該requestの完了pulse。 |
| `rsp_rdata[15:0]` | read data。hostは`req_be`で選択されたlaneだけを使用する。 |
| `rsp_error` | read-only writeまたはbackend decode error。 |

MVP直結portにtagはないため、同期backendは順序を変えず一件だけ返す。`ws003p002`の[CDC・AXI4-Lite契約](cdc-axil-contract.md)ではCDC endpointが8-bit tagを付加し、timeout後の遅延responseを隔離する。target engineのport互換性は維持する。

## 4. Cバス側安全契約

- `cbus_data_oe_req`は選択されたread cycleでresponse/timeout dataが準備できた場合だけ有効にする。
- write、非選択、不正lane、reset、`platform_ready=0`ではdata OEを無効にする。
- backendが所定cycle数以内に応答しない場合はIORDY Low要求を出す。
- timeout時はIORDYを解放し、readでは`16'hffff`を返し、sticky statusを立てて永久waitを避ける。
- `platform_ready`低下またはresetはactive cycleをabortし、RTL stateに依存せずOE requestを即時gateする。
- 物理board topはこれらのrequestをさらにreset、clock lock、bus permitでgateする。
- `CBUS_MEM_ENABLE=0`では`SALE/MRC/MWC/MWE`がrequest、DB OE、IORDY OEを生成しない。
- memory readは`MRC`だけ、memory writeは同一cycleの`MWC+MWE`だけでrequestを生成する。`MWC`だけではcommitしない。
- memory upper address latchはresetまたは`platform_ready=0`で無効化し、次のlogical active-high `SALE` pulseまでmemory cycleへ応答しない。

## 5. CSR map

既定baseは`0x00d0`、8 byte windowである。これはシミュレーション用の仮値で、実機I/O資源選定前には固定しない。

| Offset | Access | Reset | Meaning |
| --- | --- | --- | --- |
| `+0x0` | R | `0xcb98` | 固定ID |
| `+0x2` | R | `0x0001` | MVP version |
| `+0x4` | RW, byte-enable | `0x0000` | scratch |
| `+0x6` | R | dynamic | bit0 timeout、bit1 invalid lane/cycle、bit2 backend error、bit3 abort |

## 6. タイミングparameter

既定の100 MHz内部clockに対し、`WAIT_ASSERT_CYCLES=4`はstrobe同期化後40 ns以内にwait requestを開始し、`TIMEOUT_CYCLES=600`は6 usで内部timeoutする。これはS001のIORDY Low最大7 usより短い論理budgetであり、LVC/配線/実機差を含む最終値ではない。BFMは短縮parameterを使ってtimeout pathを高速検証する。
