#!/usr/bin/env python3
"""Build the board-independent endpoint set and Primer/Mega connector maps."""

from __future__ import annotations

import csv
from pathlib import Path


WS001 = Path(__file__).resolve().parents[1]
PLAN = WS001.parent
WS002 = PLAN / "ws002-fpga-platform"


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)


signals = {row["pin"]: row for row in read_csv(WS001 / "signal-matrix.csv")}


def bus_endpoint(
    endpoint: str,
    pin: str,
    common_port: str,
    direction: str,
    electrical_path: str,
    introduced_by: str,
    notes: str = "",
) -> dict[str, str]:
    row = signals[pin]
    return {
        "endpoint": endpoint,
        "endpoint_kind": "cbus_signal",
        "cbus_pin_or_selector": pin,
        "signal_8086": row["signal_8086"],
        "signal_286_plus": row["signal_286_plus"],
        "common_port": common_port,
        "translator_group": row["translator_group"],
        "fpga_pin_direction": direction,
        "electrical_path": electrical_path,
        "introduced_by": introduced_by,
        "notes": notes,
    }


def virtual_endpoint(
    endpoint: str,
    selector: str,
    signals_8086: str,
    signals_286: str,
    common_port: str,
    group: str,
    direction: str,
    electrical_path: str,
    introduced_by: str,
    notes: str,
) -> dict[str, str]:
    return {
        "endpoint": endpoint,
        "endpoint_kind": "carrier_selected_signal",
        "cbus_pin_or_selector": selector,
        "signal_8086": signals_8086,
        "signal_286_plus": signals_286,
        "common_port": common_port,
        "translator_group": group,
        "fpga_pin_direction": direction,
        "electrical_path": electrical_path,
        "introduced_by": introduced_by,
        "notes": notes,
    }


def control_endpoint(endpoint: str, common_port: str, introduced_by: str, notes: str) -> dict[str, str]:
    return {
        "endpoint": endpoint,
        "endpoint_kind": "lvc_control",
        "cbus_pin_or_selector": "n/a",
        "signal_8086": "n/a",
        "signal_286_plus": "n/a",
        "common_port": common_port,
        "translator_group": "lvc_control",
        "fpga_pin_direction": "output",
        "electrical_path": "safe_oe_or_dir_control",
        "introduced_by": introduced_by,
        "notes": notes,
    }


endpoints: list[dict[str, str]] = []

address_pins = [f"A{p}" for p in list(range(4, 11)) + list(range(12, 21)) + list(range(22, 30))]
for bit, pin in enumerate(address_pins):
    introduced = "io8_sync_min" if bit < 16 else "mem8_20bit_min" if bit < 20 else "target24_full"
    endpoints.append(bus_endpoint(
        f"cbus_ab_{bit:02d}", pin, f"cbus_ab_i/o/oe_req[{bit}]", "bidir",
        "lvc_bidir", introduced,
    ))

data_pins = [f"B{p}" for p in list(range(4, 11)) + list(range(12, 21))]
for bit, pin in enumerate(data_pins):
    introduced = "io8_sync_min" if bit < 8 else "io16_sync_min"
    endpoints.append(bus_endpoint(
        f"cbus_db_{bit:02d}", pin, f"cbus_db_i/o/oe_req[{bit}]", "bidir",
        "lvc_bidir", introduced,
    ))

for args in (
    ("cbus_ior_n", "A33", "cbus_ior_n_i/o/oe_req", "bidir", "lvc_bidir", "io8_sync_min"),
    ("cbus_iow_n", "A34", "cbus_iow_n_i/o/oe_req", "bidir", "lvc_bidir", "io8_sync_min"),
    ("cbus_mrc_n", "A35", "cbus_mrc_n_i/o/oe_req", "bidir", "lvc_bidir", "mem8_20bit_min"),
    ("cbus_mwc_n", "A36", "cbus_mwc_n_i/o/oe_req", "bidir", "lvc_bidir", "mem8_20bit_min"),
    ("cbus_mwe_n", "B45", "cbus_mwe_n_i/o/oe_req", "bidir", "lvc_bidir", "mem8_20bit_min"),
    ("cbus_bhe_n", "A44", "cbus_bhe_n_i/o/oe_req", "bidir", "lvc_bidir", "io16_sync_min"),
    ("cbus_reset_n", "B34", "cbus_reset_n_i", "input", "lvc_input", "io8_sync_min"),
    ("cbus_power_n", "A48", "cbus_power_n_i", "input", "lvc_input", "io8_sync_min"),
    ("cbus_sclk", "A46", "cbus_sclk_i", "input", "lvc_input", "io8_sync_min"),
    ("cbus_iordy", "A45", "cbus_iordy_o", "output", "lvc_tristate_output", "io8_sync_min"),
):
    endpoints.append(bus_endpoint(*args))

endpoints.append(virtual_endpoint(
    "cbus_irq_selected", "IRQ selector: B24/B25/B26/B27/B28/B29/B30",
    "IR3/IR5/IR6/IR9/IR10|IR11/IR12/IR13", "IR3/IR5/IR6/IR9/IR10/IR12/IR13",
    "cbus_irq_assert", "irq_selected", "output", "carrier_selects_tristate_or_open_drain_path",
    "io8_sync_min", "IRQ number and TS/OC output path remain a carrier setting; no IRQ pin is hard-coded in common IP.",
))

endpoints.extend((
    virtual_endpoint(
        "cbus_dack_selected_n", "DACK selector: B35/B36", "DACK0/DACK2|DACK3", "DACK0/DACK3",
        "cbus_dack_n_i", "dma_in", "input", "carrier_selected_lvc_input", "target24_dma",
        "DMA channel/slot mapping remains a carrier setting.",
    ),
    virtual_endpoint(
        "cbus_drq_selected_n", "DRQ selector: B37/B38", "DRQ0/DRQ2|DRQ3", "DRQ0/DRQ3",
        "cbus_drq_n_assert", "dma_out_oc", "output", "carrier_selected_open_drain", "target24_dma",
        "DMA channel/slot mapping remains a carrier setting.",
    ),
    bus_endpoint("cbus_word_n", "B39", "cbus_word_n_o", "output", "lvc_tristate_output", "target24_dma"),
    bus_endpoint("cbus_dmatc_n", "B43", "cbus_dmatc_n_i", "input", "lvc_input", "target24_dma"),
))

endpoints.extend((
    bus_endpoint(
        "cbus_b40_exhrq1_n", "B40", "cbus_exhrq1_n_assert", "output", "open_drain_286_plus",
        "target24_busmaster", "This profile reserves the 286+ EXHRQ1 use; 8086 CPKILL tri-state output needs a separate later profile/path.",
    ),
    bus_endpoint("cbus_b47_exhrq2_n", "B47", "cbus_exhrq2_n_assert", "output", "open_drain_286_plus", "target24_busmaster",
                 "This profile reserves the 286+ EXHRQ2 use; 8086 HRQ tri-state output needs a separate later profile/path."),
    bus_endpoint("cbus_b42_exhla1_n", "B42", "cbus_exhla1_n_i", "input", "lvc_input_286_plus", "target24_busmaster"),
    bus_endpoint("cbus_b46_exhla2_n", "B46", "cbus_exhla2_n_i", "input", "lvc_input_286_plus", "target24_busmaster"),
    bus_endpoint("cbus_b48_sbusrq", "B48", "cbus_sbusrq_i", "input", "lvc_input_286_plus", "target24_busmaster"),
))

endpoints.extend((
    control_endpoint("lvc_data_dir", "safe_drive_if.data_dir", "io8_sync_min", "Direction is separately controlled from OE."),
    control_endpoint("lvc_data_oe_n", "safe_drive_if.data_oe_n", "io8_sync_min", "External pull-up makes configuration default High-Z."),
    control_endpoint("lvc_iordy_oe_n", "safe_drive_if.iordy_oe_n", "io8_sync_min", "IORDY cycle window cannot share IRQ OE."),
    control_endpoint("lvc_irq_oe_n", "safe_drive_if.irq_oe_n", "io8_sync_min", "Used only for a selected tri-state IRQ path; IR9 uses open drain."),
    control_endpoint("lvc_word_oe_n", "safe_drive_if.word_oe_n", "target24_dma", "WORD has an independent DMA-active window."),
    control_endpoint("lvc_addr_dir", "safe_drive_if.addr_dir", "target24_busmaster", "Passive target default is host-to-FPGA."),
    control_endpoint("lvc_addr_oe_n", "safe_drive_if.addr_oe_n", "target24_busmaster", "External pull-up makes configuration default High-Z."),
    control_endpoint("lvc_cmd_dir", "safe_drive_if.cmd_dir", "target24_busmaster", "Passive target default is host-to-FPGA."),
    control_endpoint("lvc_cmd_oe_n", "safe_drive_if.cmd_oe_n", "target24_busmaster", "External pull-up makes configuration default High-Z."),
))

for index, endpoint in enumerate(endpoints, 1):
    endpoint["endpoint_index"] = str(index)

# Rebuild ordinary dict order with endpoint_index first.
endpoints = [{"endpoint_index": row.pop("endpoint_index"), **row} for row in endpoints]


def available(board_file: str, banks: list[str]) -> dict[str, list[dict[str, str]]]:
    rows = read_csv(WS002 / board_file)
    return {
        # Source CSV order follows the schematic connector order and keeps each
        # group physically clustered better than lexical connector sorting.
        bank: [row for row in rows if row["cbus_assignable"] == "yes" and row["bank"] == bank]
        for bank in banks
    }


primer = available("tang-primer-20k-sodimm.csv", ["0", "1", "2", "3", "7"])
mega = available("tang-mega-138k-btb.csv", ["2", "3", "4"])

# Endpoint order is 24 address, 16 data, 20 other C-bus paths, 9 controls.
primer_pins = primer["0"] + primer["2"][:2] + primer["7"] + primer["1"] + primer["3"][:9]
mega_pins = mega["2"][:24] + mega["3"][:16] + mega["4"][:29]


def board_map(board: str, pins: list[dict[str, str]]) -> list[dict[str, str]]:
    assert len(endpoints) == 69
    assert len(pins) == len(endpoints)
    rows = []
    for endpoint, pin in zip(endpoints, pins):
        rows.append({
            "endpoint_index": endpoint["endpoint_index"],
            "endpoint": endpoint["endpoint"],
            "endpoint_kind": endpoint["endpoint_kind"],
            "common_port": endpoint["common_port"],
            "translator_group": endpoint["translator_group"],
            "fpga_pin_direction": endpoint["fpga_pin_direction"],
            "connector": pin["connector"],
            "connector_pin": pin["pin"],
            "module_net": pin["net"],
            "bank": pin["bank"],
            "io_voltage": pin["io_voltage"],
            "introduced_by": endpoint["introduced_by"],
            "board": board,
            "notes": endpoint["notes"],
        })
    return rows


write_csv(WS001 / "platform-endpoints.csv", endpoints)
write_csv(WS001 / "primer20k-platform-map.csv", board_map("tang_primer20k", primer_pins))
write_csv(WS001 / "mega138k-platform-map.csv", board_map("tang_mega138k", mega_pins))

print("generated 69 common endpoints and two 69-row board maps")
