# AXI4-Lite System CSR contract

更新日: 2026-09-01

対象: `ws003p006`

## Address mapping

既定CバスI/O base `0x00d0`の8 byte窓は、`cbus_to_axil_bridge`によりSystem CSR base `0x1000_0000`の四つの32-bit wordへ変換される。

| Cバス | AXI4-Lite | Register | lower 16-bit Cバス値 |
| ---: | ---: | --- | ---: |
| `base+0` | `0x1000_0000` | `PRODUCT_ID` RO | `0xcb98` |
| `base+2` | `0x1000_0004` | `VERSION_CAP` RO | `0x0002` |
| `base+4` | `0x1000_0008` | `SCRATCH` RW | reset `0x0000` |
| `base+6` | `0x1000_000c` | `STATUS` RO | dynamic |

32-bit AXI値は`PRODUCT_ID=0x4342_cb98`、`VERSION_CAP=0x00ff_0002`である。`SCRATCH`はWSTRBごとにbyte更新する。Cバスeven/odd laneは既存bridgeによりWSTRB[0]/[1]へ写像される。

## STATUS lower 16 bits

| Bits | Meaning |
| --- | --- |
| 0 | Cバスtimeout sticky |
| 1 | invalid cycle sticky |
| 2 | backend error sticky |
| 3 | abort sticky |
| 4 | guard quarantined/faulted |
| 5 | guard reject sticky |
| 6 | guard timeout sticky |
| 7 | downstream AXI error sticky |
| 8 | first-fault valid |
| 9 | first-fault was write |
| 12:10 | first-fault code |
| 15:13 | zero/reserved |

Cバス側stickyはsticky levelであるため、System CSR内部の二段同期器でAXI clock domainへ移す。guard statusはAXI domainで直接取得する。

## AXI behavior

- AW/Wは独立に一件bufferし、両channel取得後に一度だけcommitする。
- VALID responseはREADY handshakeまでpayloadとともに保持する。
- `SCRATCH` writeだけOKAY。RO writeはSLVERR。
- 16-byte aperture外または非word-aligned accessはDECERR。
- resetはpending AW/W、B/R VALID、SCRATCH、status synchronizerをclearする。

## Fault recovery boundary

guard timeoutでCバス由来Managerがquarantineされると、そのManagerからSystem CSRへ到達できない。したがって`fault_clear`をこのCSRへ割り当てない。first-fault詳細、subordinate reset、明示的clearは、将来のCPU/debugまたは独立platform recovery controllerから行う。

この分離により「障害で遮断された経路を使わないと障害を解除できない」という循環依存を避ける。
