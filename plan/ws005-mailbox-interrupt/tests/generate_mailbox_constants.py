#!/usr/bin/env python3
"""Validate the mailbox ABI source and render shared SV/C/Rust constants."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "plan/ws005-mailbox-interrupt/mailbox-register-map.json"
CONTRACT = ROOT / "plan/ws005-mailbox-interrupt/mailbox-interrupt-contract.md"
OUTPUTS = {
    ROOT / "rtl/include/cbus_mailbox_regs_pkg.sv": "sv",
    ROOT / "sw/include/cbus_mailbox_regs.h": "c",
    ROOT / "sw/rust/cbus_mailbox_regs.rs": "rust",
}
VALID_ACCESS = {"RO", "RW", "W1C", "W1P", "W1S", "PUSH32"}


def number(value: str | int) -> int:
    return int(value, 0) if isinstance(value, str) else value


def load_and_validate() -> dict:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    if (data["schema_version"] != 1 or data["abi_version"] != 1
            or data["register_width_bits"] != 32):
        raise ValueError("only schema/ABI version 1 with 32-bit registers is accepted")

    blocks: dict[str, tuple[int, int]] = {}
    occupied: list[tuple[int, int, str]] = []
    for block in data["blocks"]:
        name = block["name"]
        base = number(block["base"])
        size = number(block["size"])
        if name in blocks or base & 0xfff or size != 0x1000:
            raise ValueError(f"invalid or duplicate block {name}")
        for old_base, old_size, old_name in occupied:
            if max(base, old_base) < min(base + size, old_base + old_size):
                raise ValueError(f"blocks overlap: {name}/{old_name}")
        blocks[name] = (base, size)
        occupied.append((base, size, name))

    registers: dict[str, dict] = {}
    offsets: set[tuple[str, int]] = set()
    for register in data["registers"]:
        block = register["block"]
        key = f"{block}_{register['name']}"
        offset = number(register["offset"])
        reset = number(register["reset"])
        if block not in blocks or key in registers or (block, offset) in offsets:
            raise ValueError(f"invalid or duplicate register {key}")
        if offset & 3 or not 0 <= offset < blocks[block][1]:
            raise ValueError(f"unaligned/out-of-range register {key}")
        if register["access"] not in VALID_ACCESS or not 0 <= reset <= 0xffff_ffff:
            raise ValueError(f"invalid access/reset for {key}")
        if not register.get("owner"):
            raise ValueError(f"missing owner for {key}")
        registers[key] = register
        offsets.add((block, offset))

    fields: set[str] = set()
    for field in data["fields"]:
        key = f"{field['register']}_{field['name']}"
        mask = number(field["mask"])
        if field["register"] not in registers or key in fields or not 0 < mask <= 0xffff_ffff:
            raise ValueError(f"invalid or duplicate field {key}")
        fields.add(key)

    event_ids: set[int] = set()
    event_names: set[str] = set()
    destination_masks = {"cpu": 0, "host": 0}
    for event in data["event_sources"]:
        event_id = event["id"]
        destination = event["destination"]
        if not 0 <= event_id < 32 or event_id in event_ids:
            raise ValueError(f"invalid or duplicate event id {event_id}")
        if event["name"] in event_names or destination not in destination_masks:
            raise ValueError(f"invalid or duplicate event {event['name']}")
        if not 0 <= event["priority"] <= 7:
            raise ValueError(f"invalid priority for {event['name']}")
        event_ids.add(event_id)
        event_names.add(event["name"])
        destination_masks[destination] |= 1 << event_id

    declared_masks = {
        "cpu": next(number(f["mask"]) for f in data["fields"]
                    if f["register"] == "INTR_CPU_PENDING"),
        "host": next(number(f["mask"]) for f in data["fields"]
                     if f["register"] == "INTR_HOST_PENDING"),
    }
    if destination_masks != declared_masks:
        raise ValueError(f"event masks differ: {destination_masks!r} != {declared_masks!r}")

    aliases: set[int] = set()
    alias_names: set[str] = set()
    for alias in data["cbus_aliases"]:
        offset = number(alias["offset"])
        if offset & 1 or not 0 <= offset < 0x20 or offset in aliases:
            raise ValueError(f"invalid or duplicate C-bus alias offset {offset:#x}")
        if alias["name"] in alias_names or alias["access"] not in VALID_ACCESS:
            raise ValueError(f"invalid or duplicate C-bus alias {alias['name']}")
        if not alias["target"].startswith("synthetic_") and alias["target"] not in registers:
            raise ValueError(f"unknown alias target {alias['target']}")
        aliases.add(offset)
        alias_names.add(alias["name"])

    contract = CONTRACT.read_text(encoding="utf-8")
    documented = (
        [register["name"] for register in data["registers"]]
        + [event["name"] for event in data["event_sources"]]
        + [alias["name"] for alias in data["cbus_aliases"]]
    )
    missing = sorted({name for name in documented if f"`{name}`" not in contract})
    if missing:
        raise ValueError(f"contract does not name canonical entries: {missing}")
    for rule in ("set wins", "no fall-through", "resetが勝つ", "pending & new mask"):
        if rule not in contract:
            raise ValueError(f"contract is missing collision rule: {rule}")

    return data


def constants(data: dict) -> list[tuple[str, int]]:
    values: list[tuple[str, int]] = [
        ("ABI_VERSION", data["abi_version"]),
        ("REGISTER_BITS", data["register_width_bits"]),
    ]
    block_bases = {b["name"]: number(b["base"]) for b in data["blocks"]}
    for block in data["blocks"]:
        values.extend([
            (f"{block['name']}_BASE", number(block["base"])),
            (f"{block['name']}_SIZE", number(block["size"])),
        ])
    values.extend((item["name"], number(item["value"])) for item in data["constants"])
    for register in data["registers"]:
        prefix = f"{register['block']}_{register['name']}"
        offset = number(register["offset"])
        values.extend([
            (f"{prefix}_OFFSET", offset),
            (f"{prefix}_ADDR", block_bases[register["block"]] + offset),
            (f"{prefix}_RESET", number(register["reset"])),
        ])
    values.extend(
        (f"{field['register']}_{field['name']}_MASK", number(field["mask"]))
        for field in data["fields"]
    )
    for event in data["event_sources"]:
        values.extend([
            (f"EVENT_{event['name']}_BIT", event["id"]),
            (f"EVENT_{event['name']}_MASK", 1 << event["id"]),
            (f"EVENT_{event['name']}_PRIORITY", event["priority"]),
        ])
    values.extend(
        (f"CBUS_ALIAS_{alias['name']}_OFFSET", number(alias["offset"]))
        for alias in data["cbus_aliases"]
    )
    return values


def render_sv(data: dict) -> str:
    lines = [
        "// Generated from plan/ws005-mailbox-interrupt/mailbox-register-map.json.",
        "// Do not edit by hand.",
        "`timescale 1ns/1ps",
        "package cbus_mailbox_regs_pkg;",
    ]
    lines.extend(f"    localparam logic [31:0] {name} = 32'h{value:08x};"
                 for name, value in constants(data))
    lines.extend(["endpackage", ""])
    return "\n".join(lines)


def render_c(data: dict) -> str:
    lines = [
        "/* Generated from plan/ws005-mailbox-interrupt/mailbox-register-map.json. */",
        "/* Do not edit by hand. */",
        "#ifndef CBUS_MAILBOX_REGS_H",
        "#define CBUS_MAILBOX_REGS_H",
        "",
        "#include <stdint.h>",
        "",
    ]
    lines.extend(
        f"#define {name if name.startswith('CBUS_') else f'CBUS_{name}'} "
        f"UINT32_C(0x{value:08x})"
        for name, value in constants(data)
    )
    lines.extend(["", "#endif", ""])
    return "\n".join(lines)


def render_rust(data: dict) -> str:
    lines = [
        "// Generated from plan/ws005-mailbox-interrupt/mailbox-register-map.json.",
        "// Do not edit by hand.",
        "#![allow(dead_code)]",
        "",
    ]
    lines.extend(
        f"pub const {name if name.startswith('CBUS_') else f'CBUS_{name}'}: "
        f"u32 = 0x{value:08x};"
        for name, value in constants(data)
    )
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="rewrite generated files")
    args = parser.parse_args()
    data = load_and_validate()
    renderers = {"sv": render_sv, "c": render_c, "rust": render_rust}
    mismatches: list[Path] = []
    for path, language in OUTPUTS.items():
        expected = renderers[language](data)
        if args.write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(expected, encoding="utf-8")
        elif not path.exists() or path.read_text(encoding="utf-8") != expected:
            mismatches.append(path)
    if mismatches:
        for path in mismatches:
            print(f"STALE: {path.relative_to(ROOT)}", file=sys.stderr)
        return 1
    print(f"PASS: mailbox ABI v{data['abi_version']}, "
          f"{len(data['registers'])} registers, "
          f"{len(data['event_sources'])} events, "
          f"{len(data['cbus_aliases'])} C-bus aliases")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
