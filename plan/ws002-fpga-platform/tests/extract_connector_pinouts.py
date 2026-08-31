#!/usr/bin/env python3
"""Extract connector maps from pdftotext -bbox-layout XHTML.

The coordinates are tied to the cited Sipeed schematic revisions.  This script
is a reproducible extraction aid; validate_pinouts.py checks the committed CSVs
without requiring the disposable PDF/XHTML files.
"""

from __future__ import annotations

import argparse
import csv
import re
import xml.etree.ElementTree as ET
from pathlib import Path

NS = "{http://www.w3.org/1999/xhtml}"


def words(path: Path) -> list[tuple[float, float, str]]:
    result = []
    for word in ET.parse(path).getroot().iter(NS + "word"):
        result.append((float(word.attrib["xMin"]), float(word.attrib["yMin"]), word.text or ""))
    return result


def pin_word(items, number, xmin, xmax, ymin, ymax):
    matches = [(x, y) for x, y, text in items if text == str(number) and xmin <= x <= xmax and ymin <= y <= ymax]
    if len(matches) != 1:
        raise ValueError(f"pin {number}: expected one coordinate, got {matches}")
    return matches[0]


def nearby(items, ymin, xmin, xmax):
    values = [(x, text) for x, y, text in items if xmin <= x <= xmax and ymin + 0.15 <= y <= ymin + 4.2]
    return [text for _, text in sorted(values)]


def first_useful(values):
    if len(values) >= 2 and values[0].endswith("_W") and re.match(r"[0-9]+_IO", values[1]):
        values = [values[0] + values[1], *values[2:]]
    ignored = {"Romove", "before", "input", "other", "voltage", "R5", "R9", "Shenzhen", "Sipeed", "Sheet:", "/"}
    values = [v for v in values if v not in ignored and not re.fullmatch(r"[0-9]+/[A-Z0-9_/]+", v)]
    return values[0] if values else "NC"


def last_useful(values):
    ignored = {"Romove", "before", "input", "other", "voltage", "R5", "R9", "Shenzhen", "Sipeed", "Sheet:", "/"}
    values = [v for v in values if v not in ignored and not re.fullmatch(r"[0-9]+/[A-Z0-9_/]+", v)]
    return values[-1] if values else "NC"


def primer_type(net):
    if net == "NC":
        return "nc"
    if net == "GND":
        return "ground"
    if net.startswith("+") or net.startswith("F_VCCO"):
        return "power"
    if "JTAG" in net:
        return "jtag"
    if "FPGA_~{RST}" in net:
        return "reset"
    if any(tag in net for tag in ("RECFG", "READY", "DONE", "FASTRD")):
        return "configuration"
    if "RPLL" in net:
        return "clock_input"
    if "_1V5" in net:
        return "input_only_1v5"
    return "gpio_bidir_3v3"


def extract_primer(path: Path):
    items = words(path)
    rows = []
    for number in range(1, 205):
        if number <= 72:
            odd = number % 2
            x, y = pin_word(items, number, 1462 if odd else 1505, 1473 if odd else 1514, 630, 900)
            candidates = nearby(items, y, 1365, 1462) if odd else nearby(items, y, 1515, 1600)
            net = last_useful(candidates) if odd else first_useful(candidates)
        else:
            odd = number % 2
            x, y = pin_word(items, number, 1200 if odd else 1244, 1210 if odd else 1252, 630, 1120)
            candidates = nearby(items, y, 1115, 1195) if odd else nearby(items, y, 1260, 1395)
            net = last_useful(candidates) if odd else first_useful(candidates)
        kind = primer_type(net)
        bank_match = re.search(r"(?:^|_)([0-7])/(?:IO|IOR|IOT|IOB|IOL)", "_".join(candidates))
        bank = bank_match.group(1) if bank_match else ""
        rows.append({
            "connector": "SO-DIMM-204",
            "pin": number,
            "net": net,
            "kind": kind,
            "bank": bank,
            "io_voltage": "1.5V" if kind == "input_only_1v5" else ("3.3V" if kind.startswith("gpio_bidir") else ""),
            "cbus_assignable": "yes" if kind == "gpio_bidir_3v3" else "no",
            "source": "Tang_Primer_20K_SOM-3961_Schematic.pdf",
        })
    return rows


def mega_type(net):
    if net == "NC":
        return "nc"
    if net == "GND":
        return "ground"
    if net in {"5V0", "VCCIO2", "VCCIO3", "VCCIO4", "VCCIO5"}:
        return "power"
    if re.search(r"BANK[234]_.+_IO[RB][0-9]+[AB]", net):
        return "gpio_bidir_3v3"
    if net.startswith("BANK5_"):
        return "bank5_unconfirmed"
    if "JTAG" in net:
        return "jtag"
    if net.startswith("BANK10_"):
        return "configuration"
    if net.startswith("Q0_"):
        return "serdes"
    if "ADC" in net:
        return "adc"
    return "other"


MEGA_CONNECTORS = (
    ("C2399", 100, (186, 194), (254, 260), (110, 180), (265, 340), (130, 395)),
    ("C2400", 100, (433, 442), (500, 507), (365, 432), (510, 620), (125, 390)),
    ("BTB9900", 80, (680, 689), (722, 729), (610, 680), (732, 820), (155, 370)),
)


def extract_mega(path: Path):
    items = words(path)
    rows = []
    for connector, total, lx, rx, lnet, rnet, yrange in MEGA_CONNECTORS:
        for number in range(1, total + 1):
            left = number % 2
            x, y = pin_word(items, number, *(lx if left else rx), *yrange)
            net = first_useful(nearby(items, y, *(lnet if left else rnet)))
            kind = mega_type(net)
            bank_match = re.match(r"BANK([0-9]+)_", net)
            rows.append({
                "connector": connector,
                "pin": number,
                "net": net,
                "kind": kind,
                "bank": bank_match.group(1) if bank_match else "",
                "io_voltage": "3.3V" if kind == "gpio_bidir_3v3" else "",
                "cbus_assignable": "yes" if kind == "gpio_bidir_3v3" else "no",
                "source": "tang_mega_138k_30353_Schematics.pdf sheet 6",
            })
    return rows


def write_csv(path: Path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--primer-xhtml", type=Path, required=True)
    parser.add_argument("--mega-xhtml", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    write_csv(args.output_dir / "tang-primer-20k-sodimm.csv", extract_primer(args.primer_xhtml))
    write_csv(args.output_dir / "tang-mega-138k-btb.csv", extract_mega(args.mega_xhtml))


if __name__ == "__main__":
    main()
