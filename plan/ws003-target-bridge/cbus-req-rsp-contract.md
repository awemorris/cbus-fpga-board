# `cbus_req/cbus_rsp` MVP契約

最終更新: 2026-09-01

対象Phase: [`ws003p001`](phase001-bfm-target-mvp/phase.md)

## 1. 境界

`cbus_target_engine`は非同期なCバスI/O cycleを内部clock domainの一件のrequestへ正規化する。MVPではAXI、CDC FIFO、memory cycleを含めず、`cbus_target_regs`を同期backendとして接続する。Primer/Megaのpin、PLL、LVC primitiveを参照しない。

## 2. Request

| Signal | Meaning |
| --- | --- |
| `req_valid` | request fieldsが有効。`req_ready`と同時Highのclock edgeで受理される。 |
| `req_ready` | backendがrequestを受理可能。 |
| `req_write` | 1=I/O write、0=I/O read。 |
| `req_addr[15:0]` | CバスI/O address。`AB00`をbit 0に保持する。 |
| `req_wdata[15:0]` | write cycleでcaptureしたDB。 |
| `req_be[1:0]` | `{upper,lower}`。`upper=~BHE0`、`lower=~AB00`。`00`は不正。 |

`req_valid`は受理まで保持する。一つのCバスcycleにつき最大一requestとし、outstandingは一件に限定する。

## 3. Response

| Signal | Meaning |
| --- | --- |
| `rsp_valid` | 当該requestの完了pulse。 |
| `rsp_rdata[15:0]` | read data。hostは`req_be`で選択されたlaneだけを使用する。 |
| `rsp_error` | read-only writeまたはbackend decode error。 |

Responseにtagはないため、MVP backendは順序を変えず一件だけ返す。複数outstanding、CDC、tag、AXI response変換は`ws003p002`以降で追加する。

## 4. Cバス側安全契約

- `cbus_data_oe_req`は選択されたread cycleでresponse/timeout dataが準備できた場合だけ有効にする。
- write、非選択、不正lane、reset、`platform_ready=0`ではdata OEを無効にする。
- backendが所定cycle数以内に応答しない場合はIORDY Low要求を出す。
- timeout時はIORDYを解放し、readでは`16'hffff`を返し、sticky statusを立てて永久waitを避ける。
- `platform_ready`低下またはresetはactive cycleをabortし、RTL stateに依存せずOE requestを即時gateする。
- 物理board topはこれらのrequestをさらにreset、clock lock、bus permitでgateする。

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
