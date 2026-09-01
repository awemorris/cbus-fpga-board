#!/usr/bin/env python3
"""Validate the user RISC-V core slot ABI and safe stub structure."""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
STUB = ROOT / "rtl/cpu/riscv_core_ip_stub.sv"
MANIFEST = ROOT / "plan/ws004-soc-runtime/riscv-core-port-manifest.csv"


def normalize_range(value: str | None) -> str:
    if not value:
        return "scalar"
    return re.sub(r"\s+", "", value)


def main() -> None:
    text = STUB.read_text(encoding="utf-8")
    assert re.search(r"\bmodule\s+riscv_core_ip_stub\s*#\s*\(", text)

    parameter_pattern = re.compile(
        r"parameter\s+integer\s+(AXI_(?:ADDR|DATA|ID)_WIDTH)\s*=\s*(\d+)"
    )
    parameters = {name: int(value) for name, value in parameter_pattern.findall(text)}
    assert parameters == {
        "AXI_ADDR_WIDTH": 32,
        "AXI_DATA_WIDTH": 32,
        "AXI_ID_WIDTH": 2,
    }, f"unexpected parameters: {parameters}"

    port_pattern = re.compile(
        r"^\s*(input|output)\s+logic(?:\s+\[([^\]]+)\])?\s+"
        r"([A-Za-z_][A-Za-z0-9_]*)\s*(?:,|$)",
        re.MULTILINE,
    )
    actual = {
        name: (direction, normalize_range(bit_range))
        for direction, bit_range, name in port_pattern.findall(text)
    }

    with MANIFEST.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    expected = {
        row["name"]: (row["direction"], normalize_range(row["range"]))
        for row in rows
    }
    assert len(expected) == len(rows), "duplicate port name in manifest"
    assert actual == expected, (
        f"port ABI mismatch\nmissing={sorted(expected.keys() - actual.keys())}"
        f"\nextra={sorted(actual.keys() - expected.keys())}"
        f"\nchanged={sorted(name for name in expected.keys() & actual.keys() if expected[name] != actual[name])}"
    )
    assert all(row["required"] == "yes" for row in rows)

    forbidden = re.compile(r"\b(cbus|primer|mega|gowin|mailbox|ddr)\b", re.IGNORECASE)
    code_without_comments = re.sub(r"//.*", "", text)
    assert not forbidden.search(code_without_comments), "platform term leaked into core stub"
    assert " initial " not in f" {code_without_comments} ", "stub must not contain startup behavior"

    required_constants = {
        "core_sleep_o": "1'b0",
        "core_halted_o": "1'b1",
        "core_trap_valid_o": "1'b0",
        "core_trap_cause_o": "32'h0000_0000",
        "core_trap_pc_o": "32'h0000_0000",
        "m_axi_awvalid_o": "1'b0",
        "m_axi_wvalid_o": "1'b0",
        "m_axi_bready_o": "1'b0",
        "m_axi_arvalid_o": "1'b0",
        "m_axi_rready_o": "1'b0",
    }
    for signal, value in required_constants.items():
        assert re.search(rf"\b{signal}\s*=\s*{re.escape(value)}\s*;", text), (
            f"missing safe assignment {signal}={value}"
        )

    output_names = {name for name, (direction, _) in expected.items() if direction == "output"}
    assigned_names = set(re.findall(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=", text, re.MULTILINE))
    assert output_names <= assigned_names, f"unassigned outputs: {sorted(output_names - assigned_names)}"

    groups: dict[str, int] = {}
    for row in rows:
        groups[row["group"]] = groups.get(row["group"], 0) + 1
    print(
        "PASS: RISC-V core slot ABI "
        f"{len(rows)} ports / 3 parameters / groups={groups}"
    )


if __name__ == "__main__":
    main()
