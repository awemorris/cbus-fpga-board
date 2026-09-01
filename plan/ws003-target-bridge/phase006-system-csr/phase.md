# ws003p006: AXI4-Lite System CSR subordinate

最終更新: 2026-09-01

Status: completed

Parent: [WS003](../ws.md)

Queue: `Q20260901-010`

## Scope

既存Cバス8-byte I/O窓が変換するAXI4-Lite四wordへ、board-independent System CSR subordinateを実装し、`cbus_ip_top`内でguardの下流へ接続する。

含めるもの:

- `0x1000_0000` ID、`+0x4` version/capability、`+0x8` scratch、`+0xC` status。
- 32-bit AXI4-Lite、AW/W独立受理、B/R backpressure、byte strobe。
- write禁止registerのSLVERR、範囲外・unaligned accessのDECERR。
- Cバス/guard sticky summaryのread-only status。
- Primer/Mega board topからID/version/scratch/statusを同じ結果で読書きする統合BFM。

含めないもの:

- mailbox、IRQ、DMA、user IP、複数target interconnect。
- CバスI/O窓拡張、実I/O base決定、memory cycle。
- guard quarantineを同じCバス経路からclearすること。
- CPU/firmware、Gowin合成、実機試験。

## Purpose and goal

前Queueの暫定DECERR targetを実際のSystem CSRへ置き換え、CバスからCDC/guard/AXI4-Liteを通した基準ID、version、scratch、status accessを両board topで再現できるようにする。

## Fixed register contract

| AXI offset | Cバスoffset | Name | Access | Reset | Meaning |
| ---: | ---: | --- | --- | ---: | --- |
| `0x00` | `+0` | `PRODUCT_ID` | RO | `0x4342_CB98` | upper=`CB` ASCII、lower=PC-98識別値。 |
| `0x04` | `+2` | `VERSION_CAP` | RO | parameter | lower16=ABI version、upper16=capability。 |
| `0x08` | `+4` | `SCRATCH` | RW | `0` | WSTRB byte更新。Cバスからはlower16を使用。 |
| `0x0C` | `+6` | `STATUS` | RO | dynamic | Cバス/guard sticky summary。 |

Status lower16:

- bit 0 Cバスtimeout sticky
- bit 1 invalid-cycle sticky
- bit 2 backend-error sticky
- bit 3 abort sticky
- bit 4 guard faulted
- bit 5 guard reject sticky
- bit 6 guard timeout sticky
- bit 7 guard downstream-error sticky
- bit 8 guard first-fault valid
- bit 9 guard first-fault write
- bits 12:10 guard first-fault code
- bits 15:13 reserved zero

Capability lower meaning within upper16:

- bit 0 passive I/O target
- bit 1 8-bit lanes
- bit 2 16-bit transfer
- bit 3 dual-clock CDC
- bit 4 AXI4-Lite guard/timeout
- bit 5 24-bit physical address contract
- bit 6 DMA pins reserved but engine disabled
- bit 7 286+ bus-master pins reserved but engine disabled

## Implementation policy

- System CSRは`rtl/ip/`に置き、board top、package、vendor名を含めない。
- `cbus_ip_top`がCSRを所有し、board/platform layerへAXI CSR terminationを押し出さない。
- read data/responseとwrite responseはVALID中READYまで不変に保つ。
- AW/Wは任意順で一件ずつbufferし、両方が揃ってからwriteをcommitする。
- STATUSは観測専用とし、sticky clearはsystem resetまたは将来の独立管理経路へ残す。
- guard fault中は同じCバスManagerがlocal error化されるため、fault clearをこのCSR writeに割り当てない。

## Completion conditions

- standalone AXI BFMで全register、AW/W順序、WSTRB、B/R backpressure、RO/invalid/unaligned errorがPASSする。
- Cバスtop統合でID=`0xcb98`、version、scratch byte lane、statusがPrimer/Mega同値になる。
- System CSRが`cbus_ip_top`以下にあり、board shellから暫定error targetが除かれる。
- 新規test、既存3990 HDL checks、WS001/WS002 validatorがwarningなくPASSする。
- fault clear循環を作らず、未実装の独立復旧経路を計画へ明記する。

## Execution result

2026-09-01 Queue `Q20260901-010`で完了した。

- `rtl/ip/axil_system_csr.sv`へ四word CSR、AW/W独立buffer、WSTRB更新、B/R payload保持、RO SLVERR、範囲外/非整列DECERRを実装した。
- Cバスclock domainの四sticky levelを二段同期してSTATUSへ収容し、guardのquarantine/sticky/first-fault summaryを同じregisterへ配置した。
- `cbus_ip_top`がSystem CSRを所有し、guardの下流へ直接接続した。platform shellの暫定`axil_error_target`は削除した。
- Primer/Mega統合BFMでID、ABI version、clean status、scratch 16-bit write、low/high byte lane更新とreadbackの同値性を確認した。
- fault clearは同じCバス経路へ割り当てず、将来のCPU/debug/platform recovery controllerへ残した。

再現コマンド:

```sh
plan/ws003-target-bridge/tests/run_iverilog.sh
plan/ws002-fpga-platform/tests/run_iverilog.sh
python3 plan/ws001-cbus-contract/tests/validate_signal_matrix.py
python3 plan/ws001-cbus-contract/tests/validate_platform_maps.py
python3 plan/ws002-fpga-platform/tests/validate_pinouts.py
```

結果:

```text
tb_axil_system_csr: PASS: 21 checks
tb_portable_board_tops: PASS: 37 checks
WS003 current regression: 656 checks
WS002 current regression: 3377 checks
combined HDL regression: 4033 checks
all structural/pin/signal validators: PASS
```

Icarus Verilog 12.0、SystemVerilog 2012、`-Wall -Wimplicit`でwarningなし。
