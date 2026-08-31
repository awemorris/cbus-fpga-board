#!/usr/bin/env python3
"""Validate the WS001 generation-aware passive target timing contract."""

from __future__ import annotations

import csv
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read_csv(name: str) -> list[dict[str, str]]:
    with (ROOT / name).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


profiles = read_csv("timing-profiles.csv")
parameters = read_csv("timing-parameters.csv")
cycles = read_csv("cycle-contract.csv")
matrix = read_csv("signal-matrix.csv")
contract_text = (ROOT / "timing-contract.md").read_text(encoding="utf-8")

profile_ids = [row["profile_id"] for row in profiles]
require(len(profile_ids) == len(set(profile_ids)), "duplicate timing profile")
require(len(profiles) == 9, f"expected 9 timing profiles, got {len(profiles)}")
require("p98_12m_286" in profile_ids, "missing asynchronous 80286 12MHz profile")

for row in profiles:
    missing = [field for field in (
        "profile_id",
        "cpu_family",
        "cpu_mode",
        "sclk_nominal_mhz",
        "sclk_cycle_ns",
        "sclk_timing_reference",
        "target_policy",
        "source_id",
        "source_pages",
    ) if not row[field]]
    require(not missing, f"profile {row['profile_id']} has blank fields: {missing}")
    require(row["source_id"] == "S001", f"unexpected profile source: {row}")
    require(row["sclk_timing_reference"] in {"valid", "invalid_unsynchronized"}, f"bad SCLK status: {row}")
    require(row["target_policy"] in {"record_only", "target_386_only", "target"}, f"bad target policy: {row}")
    frequency = float(row["sclk_nominal_mhz"])
    period = float(row["sclk_cycle_ns"])
    require(abs(frequency * period - 1000.0) < 0.8, f"frequency/period mismatch: {row}")

profile_by_id = {row["profile_id"]: row for row in profiles}
require(
    profile_by_id["p98_12m_286"]["sclk_timing_reference"] == "invalid_unsynchronized",
    "80286 12MHz must not use SCLK as timing reference",
)
require(profile_by_id["p98_12m_286"]["target_policy"] == "record_only", "80286 must be record-only")
require(profile_by_id["p98_486_pentium"]["target_policy"] == "target", "486/Pentium must be in target set")
require(
    all(row["target_policy"] == "record_only" for row in profiles if row["cpu_family"] in {"8086-class", "70116/70116H/70136A"}),
    "pre-386 profiles must be record-only",
)

allowed_parameter_profiles = set(profile_ids) | {"all_profiles", "later_cpu_common", "external_cpu_only"}
allowed_status = {"confirmed", "unknown", "deferred"}
coverage: Counter[str] = Counter()
for row in parameters:
    require(row["profile_id"] in allowed_parameter_profiles, f"unknown parameter profile: {row}")
    require(row["cycle"], f"blank parameter cycle: {row}")
    require(row["parameter_id"], f"blank parameter ID: {row}")
    require(row["source_id"] == "S001" and row["source_pages"], f"untraceable parameter: {row}")
    require(row["status"] in allowed_status, f"bad parameter status: {row}")
    if row["status"] == "confirmed" and row["parameter_id"] != "sclk_low_pulse":
        require(row["min_ns"] or row["max_ns"], f"confirmed numeric row has no limit: {row}")
    if row["min_ns"]:
        float(row["min_ns"])
    if row["max_ns"]:
        float(row["max_ns"])
    if row["min_ns"] and row["max_ns"]:
        require(float(row["min_ns"]) <= float(row["max_ns"]), f"inverted timing range: {row}")
    coverage[row["cycle"]] += 1

for required in {"clock", "wait", "io_read", "io_write", "memory_read", "memory_write", "irq", "interrupt_ack"}:
    require(coverage[required] > 0, f"missing timing parameter coverage: {required}")

wait_width = next(row for row in parameters if row["parameter_id"] == "iordy_low_width")
require(wait_width["min_ns"] == "40" and wait_width["max_ns"] == "7000", "IORDY width changed")
irq_pulse = next(row for row in parameters if row["parameter_id"] == "request_low_pulse_before_positive_edge")
require(irq_pulse["status"] == "unknown", "IRQ pulse width must remain unknown")
inta = next(row for row in parameters if row["parameter_id"] == "inta0_timing")
require(inta["status"] == "deferred", "INTA must remain outside passive target timing")

cycle_rows: dict[str, list[dict[str, str]]] = defaultdict(list)
for row in cycles:
    missing = [field for field in (
        "cycle_id",
        "step",
        "phase",
        "observer",
        "required_condition",
        "card_action",
        "card_drive",
        "release_condition",
        "source_id",
        "source_pages",
        "status",
    ) if not row[field]]
    require(not missing, f"cycle row has blank fields: {missing}: {row}")
    require(row["source_id"] == "S001", f"unexpected cycle source: {row}")
    require(row["status"] in {"confirmed", "provisional", "deferred"}, f"bad cycle status: {row}")
    int(row["step"])
    cycle_rows[row["cycle_id"]].append(row)

required_cycles = {"io_read", "io_write", "memory_read", "memory_write", "irq_request", "interrupt_ack_boundary"}
require(required_cycles <= set(cycle_rows), f"missing cycle contracts: {required_cycles - set(cycle_rows)}")
for cycle_id, rows in cycle_rows.items():
    steps = [int(row["step"]) for row in rows]
    require(steps == list(range(len(rows))), f"non-contiguous steps for {cycle_id}: {steps}")

require(cycle_rows["io_read"][-1]["card_drive"] == "DB=Hi-Z", "I/O read must end High-Z")
require(cycle_rows["memory_read"][-1]["card_drive"] == "DB=Hi-Z", "memory read must end High-Z")
require(all("DB=input" in row["card_drive"] for row in cycle_rows["io_write"]), "I/O write must never drive DB")
require(all("DB=input" in row["card_drive"] for row in cycle_rows["memory_write"]), "memory write must never drive DB")
require(cycle_rows["interrupt_ack_boundary"][0]["status"] == "deferred", "INTA boundary changed")

matrix_signal_names = {
    row[field]
    for row in matrix
    for field in ("signal_8086", "signal_286_plus")
}
for required_signal in {"IOR0", "IOW0", "MRC0", "MWC0", "MWE0", "IORDY1", "SALE1", "INTA0", "IR31"}:
    require(required_signal in matrix_signal_names, f"timing contract signal missing from signal matrix: {required_signal}")

for required_text in (
    "invalid_unsynchronized",
    "timing-profiles.csv",
    "timing-parameters.csv",
    "cycle-contract.csv",
    "INTA0",
    "T-U001",
    "T-U005",
):
    require(required_text in contract_text, f"timing-contract.md missing {required_text}")

print(
    f"PASS: {len(profiles)} profiles; {len(parameters)} timing parameters; "
    f"{len(cycles)} cycle steps; {len(cycle_rows)} cycle contracts"
)
