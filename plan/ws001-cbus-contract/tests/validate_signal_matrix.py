#!/usr/bin/env python3
"""Validate the WS001 C-bus and Tang Nano 20K machine-readable matrices."""

from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read_csv(name: str) -> list[dict[str, str]]:
    with (ROOT / name).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


signals = read_csv("signal-matrix.csv")
groups = read_csv("translator-groups.csv")
headers = read_csv("tang-nano-20k-headers.csv")
budgets = read_csv("io-budget.csv")

expected_pins = {f"{side}{position}" for side in "AB" for position in range(1, 51)}
actual_pins = {row["pin"] for row in signals}
require(len(signals) == 100, f"signal matrix has {len(signals)} rows; expected 100")
require(actual_pins == expected_pins, f"connector pin mismatch: {sorted(expected_pins ^ actual_pins)}")

required_signal_fields = {
    "pin",
    "signal_8086",
    "signal_286_plus",
    "host_dir_8086",
    "host_dir_286_plus",
    "polarity",
    "card_drive_type",
    "role",
    "translator_group",
    "source",
    "status",
}
for row in signals:
    missing = sorted(field for field in required_signal_fields if not row[field])
    require(not missing, f"{row['pin']} has blank required fields: {missing}")

group_names = {row["group"] for row in groups}
for row in signals:
    require(row["translator_group"] in group_names, f"{row['pin']} references unknown group")

for bit in range(24):
    pin = f"A{4 + bit if bit < 7 else 5 + bit if bit < 16 else 6 + bit}"
    row = next(item for item in signals if item["pin"] == pin)
    require(row["signal_8086"] == f"AB{bit:02d}", f"{pin} address mapping mismatch")
    require(row["signal_286_plus"] == f"AB{bit:02d}", f"{pin} 286+ address mapping mismatch")

data_positions = list(range(4, 11)) + list(range(12, 21))
for bit, position in enumerate(data_positions):
    row = next(item for item in signals if item["pin"] == f"B{position}")
    require(row["signal_8086"] == f"DB{bit:02d}", f"B{position} data mapping mismatch")
    require(row["signal_286_plus"] == f"DB{bit:02d}", f"B{position} 286+ data mapping mismatch")

expected_header_positions = {(header, str(pin)) for header in ("J5", "J6") for pin in range(1, 21)}
actual_header_positions = {(row["header"], row["header_pin"]) for row in headers}
require(len(headers) == 40, f"Tang header matrix has {len(headers)} rows; expected 40")
require(actual_header_positions == expected_header_positions, "Tang J5/J6 positions are incomplete")

gpio_rows = [row for row in headers if row["kind"] == "gpio"]
fpga_pins = [row["fpga_package_pin"] for row in gpio_rows]
require(len(gpio_rows) == 34, f"Tang headers expose {len(gpio_rows)} GPIO; expected 34")
require(len(fpga_pins) == len(set(fpga_pins)), "Tang FPGA package pin appears more than once")
require(all(row["rail"] == "3V3" for row in gpio_rows), "not all exposed GPIO are on 3V3 rails")
require(all(row["clean_unshared_gpio"] == "false" for row in gpio_rows), "unexpected unshared GPIO claim")

for row in budgets:
    parts = sum(
        int(row[field])
        for field in (
            "address_pins",
            "data_pins",
            "bus_control_pins",
            "response_pins",
            "fpga_transceiver_control_pins",
        )
    )
    total = int(row["total_fpga_io"])
    tang = int(row["tang_gpio"])
    require(parts == total, f"{row['profile']} total does not match component sum")
    require(tang == 34, f"{row['profile']} uses unexpected Tang GPIO baseline")
    require(int(row["margin"]) == tang - total, f"{row['profile']} margin is incorrect")

require(all(row["status"] == "insufficient" for row in budgets), "Nano must be insufficient after independent response OE correction")
require(next(row for row in budgets if row["profile"] == "io8_sync_min")["total_fpga_io"] == "35", "8-bit minimum must include independent response OEs")
require(next(row for row in budgets if row["profile"] == "target24_dma_busmaster")["total_fpga_io"] == "69", "combined endpoint superset mismatch")

print(
    "OK: 100 C-bus pins; "
    f"{len(group_names)} translator groups; "
    "40 Tang header pins / 34 shared GPIO; "
    f"{len(budgets)} I/O profiles"
)
