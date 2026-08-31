#!/usr/bin/env python3
"""Validate common platform endpoints and the two module connector maps."""

from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path


WS001 = Path(__file__).resolve().parents[1]
WS002 = WS001.parent / "ws002-fpga-platform"


def read(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


endpoints = read(WS001 / "platform-endpoints.csv")
signals = {row["pin"]: row for row in read(WS001 / "signal-matrix.csv")}
budgets = read(WS001 / "io-budget.csv")
require(len(endpoints) == 69, f"expected 69 endpoints, got {len(endpoints)}")
require([int(row["endpoint_index"]) for row in endpoints] == list(range(1, 70)), "endpoint index mismatch")
require(len({row["endpoint"] for row in endpoints}) == 69, "duplicate endpoint")
require(Counter(row["endpoint_kind"] for row in endpoints) == Counter({
    "cbus_signal": 57,
    "carrier_selected_signal": 3,
    "lvc_control": 9,
}), "endpoint kind totals changed")
require(Counter(row["translator_group"] for row in endpoints)["addr_lo"] == 16, "address-low count")
require(Counter(row["translator_group"] for row in endpoints)["addr_hi"] == 8, "address-high count")
require(Counter(row["translator_group"] for row in endpoints)["data"] == 16, "data count")
combined = next(row for row in budgets if row["profile"] == "target24_dma_busmaster")
require(int(combined["total_fpga_io"]) == len(endpoints), "combined budget does not match endpoint set")

for row in endpoints:
    if row["endpoint_kind"] == "cbus_signal":
        require(row["cbus_pin_or_selector"] in signals, f"unknown C-bus pin: {row}")


def validate_board(
    board_map_name: str,
    source_name: str,
    expected_board: str,
    expected_banks: Counter[str],
    conservative_total: int,
) -> None:
    mapped = read(WS001 / board_map_name)
    source_rows = read(WS002 / source_name)
    source = {(row["connector"], row["pin"]): row for row in source_rows}
    require(len(mapped) == 69, f"{expected_board}: map row count")
    require([row["endpoint"] for row in mapped] == [row["endpoint"] for row in endpoints], f"{expected_board}: endpoint order")
    keys = [(row["connector"], row["connector_pin"]) for row in mapped]
    require(len(keys) == len(set(keys)), f"{expected_board}: connector pin reused")
    require(Counter(row["bank"] for row in mapped) == expected_banks, f"{expected_board}: bank allocation")
    for row, endpoint in zip(mapped, endpoints):
        require(row["board"] == expected_board, f"{expected_board}: board label")
        require(row["common_port"] == endpoint["common_port"], f"{expected_board}: port mismatch")
        pin = source[(row["connector"], row["connector_pin"])]
        require(pin["cbus_assignable"] == "yes", f"{expected_board}: unsafe source pin")
        require(pin["kind"] == "gpio_bidir_3v3", f"{expected_board}: non-GPIO source pin")
        require(pin["io_voltage"] == "3.3V", f"{expected_board}: voltage mismatch")
        require(pin["net"] == row["module_net"] and pin["bank"] == row["bank"], f"{expected_board}: source drift")
    print(f"PASS: {expected_board} maps 69 endpoints; {conservative_total - len(mapped)} conservative GPIO remain")


validate_board(
    "primer20k-platform-map.csv",
    "tang-primer-20k-sodimm.csv",
    "tang_primer20k",
    Counter({"0": 22, "2": 2, "7": 16, "1": 20, "3": 9}),
    86,
)
validate_board(
    "mega138k-platform-map.csv",
    "tang-mega-138k-btb.csv",
    "tang_mega138k",
    Counter({"2": 24, "3": 16, "4": 29}),
    144,
)

comparisons = read(WS002 / "io-platform-comparison.csv")
for row in comparisons:
    if row["margin"] == "NA":
        continue
    require(
        int(row["margin"]) == int(row["conservative_cbus_gpio"]) - int(row["total_required"]),
        f"comparison margin mismatch: {row}",
    )
    budget = next(item for item in budgets if item["profile"] == row["profile"])
    require(row["total_required"] == budget["total_fpga_io"], f"comparison total drift: {row}")
print("PASS: I/O budget and platform comparison totals agree")
