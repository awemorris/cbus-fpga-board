#!/usr/bin/env python3
"""Validate the committed Primer and Mega connector maps.

This intentionally has no dependency on the disposable source PDFs.  It checks
the row set, classifications, conservative C-bus allowance and bank totals that
the platform comparison relies on.
"""

from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(name: str) -> list[dict[str, str]]:
    with (ROOT / name).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def validate_unique(rows: list[dict[str, str]], connector_sizes: dict[str, int]) -> None:
    actual = Counter(row["connector"] for row in rows)
    assert actual == Counter(connector_sizes), (actual, connector_sizes)
    keys = [(row["connector"], int(row["pin"])) for row in rows]
    assert len(keys) == len(set(keys)), "duplicate connector pin"
    for connector, size in connector_sizes.items():
        pins = {pin for conn, pin in keys if conn == connector}
        assert pins == set(range(1, size + 1)), f"{connector}: non-contiguous pins"


def main() -> None:
    primer = read("tang-primer-20k-sodimm.csv")
    validate_unique(primer, {"SO-DIMM-204": 204})
    assert Counter(row["kind"] for row in primer) == Counter({
        "gpio_bidir_3v3": 86,
        "ground": 50,
        "nc": 43,
        "input_only_1v5": 8,
        "power": 7,
        "configuration": 4,
        "jtag": 4,
        "reset": 1,
        "clock_input": 1,
    })
    assert Counter(row["bank"] for row in primer if row["cbus_assignable"] == "yes") == Counter({
        "0": 22, "1": 20, "2": 10, "3": 18, "7": 16,
    })

    mega = read("tang-mega-138k-btb.csv")
    validate_unique(mega, {"C2399": 100, "C2400": 100, "BTB9900": 80})
    assert Counter(row["kind"] for row in mega) == Counter({
        "gpio_bidir_3v3": 144,
        "ground": 51,
        "bank5_unconfirmed": 35,
        "serdes": 20,
        "nc": 10,
        "configuration": 7,
        "power": 5,
        "adc": 4,
        "jtag": 4,
    })
    assert Counter(row["bank"] for row in mega if row["cbus_assignable"] == "yes") == Counter({
        "2": 50, "3": 50, "4": 44,
    })

    for board, rows in (("Primer", primer), ("Mega", mega)):
        for row in rows:
            if row["cbus_assignable"] == "yes":
                assert row["kind"] == "gpio_bidir_3v3", f"{board}: unsafe assignment {row}"
                assert row["io_voltage"] == "3.3V", f"{board}: voltage mismatch {row}"

    print("PASS: Primer 204 pins / 86 conservative GPIO")
    print("PASS: Mega 280 pins / 144 conservative GPIO")


if __name__ == "__main__":
    main()
