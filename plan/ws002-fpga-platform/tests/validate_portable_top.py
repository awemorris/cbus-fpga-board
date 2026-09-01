#!/usr/bin/env python3
"""Structural checks for the portable IP/board-top boundary."""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def main() -> None:
    ip = read("rtl/ip/cbus_ip_top.sv")
    shell = read("rtl/platform/cbus_board_shell.sv")
    primer = read("rtl/top/tang_primer20k_top.sv")
    mega = read("rtl/top/tang_mega138k_top.sv")

    forbidden = re.compile(r"primer|mega|gowin|gw2|gw5|\bpackage\b|\bddr\b", re.IGNORECASE)
    assert not forbidden.search(ip), "board/vendor term leaked into rtl/ip/cbus_ip_top.sv"
    assert "axil_system_csr" in ip, "System CSR is not owned by cbus_ip_top"
    assert "cbus_ip_top" in shell and "cbus_pad_adapter" in shell
    assert "axil_system_csr" not in shell, "System CSR leaked into platform shell"
    shell_instance = re.compile(r"cbus_board_shell\s*(?:#\s*\([^;]+\))?\s+shell\s*\(", re.DOTALL)
    assert shell_instance.search(primer) and shell_instance.search(mega)
    assert ".CBUS_MBX_ENABLE(CBUS_MBX_ENABLE)" in primer
    assert ".CBUS_MBX_IO_BASE(CBUS_MBX_IO_BASE)" in primer
    assert "ENABLE_RAW_CLOCK_TEST_ONLY = 1'b0" in primer
    assert "ENABLE_RAW_CLOCK_TEST_ONLY = 1'b0" in mega

    normalized_primer = primer.replace("tang_primer20k_top", "tang_board_top")
    normalized_mega = mega.replace("tang_mega138k_top", "tang_board_top")
    assert normalized_primer == normalized_mega, "board wrappers differ beyond module name"

    cst_port_pattern = re.compile(r'^IO_LOC "([^"]+)" ([A-Z]{1,2}[0-9]{1,2});$', re.MULTILINE)
    expected_ports = {"board_clk"}
    expected_ports.update(f"cbus_ab[{i}]" for i in range(24))
    expected_ports.update(f"cbus_db[{i}]" for i in range(16))
    expected_ports.update({
        "cbus_ior_n", "cbus_iow_n", "cbus_mrc_n", "cbus_mwc_n", "cbus_mwe_n",
        "cbus_bhe_n", "cbus_reset_n", "cbus_power_n", "cbus_sclk", "cbus_iordy",
        "cbus_irq_selected", "cbus_dack_selected_n", "cbus_drq_selected_n", "cbus_word_n",
        "cbus_dmatc_n", "cbus_b40_exhrq1_n", "cbus_b47_exhrq2_n",
        "cbus_b42_exhla1_n", "cbus_b46_exhla2_n", "cbus_b48_sbusrq",
        "lvc_data_dir", "lvc_data_oe_n", "lvc_iordy_oe_n", "lvc_irq_oe_n",
        "lvc_word_oe_n", "lvc_addr_dir", "lvc_addr_oe_n", "lvc_cmd_dir", "lvc_cmd_oe_n",
    })

    for board in ("primer20k", "mega138k"):
        cst = read(f"constraints/{board}/cbus.cst")
        locations = cst_port_pattern.findall(cst)
        ports = [port for port, _ in locations]
        pins = [pin for _, pin in locations]
        assert set(ports) == expected_ports and len(ports) == 70
        assert len(set(pins)) == 70, f"duplicate package location in {board}"
        with (ROOT / f"constraints/{board}/cbus-endpoints.csv").open(newline="", encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))
        assert len(rows) == 69
        assert {row["port"] for row in rows} == expected_ports - {"board_clk"}
        assert all(row["io_type"] == "LVCMOS33" for row in rows)

    print("PASS: portable top structure / 69 endpoints / 70 CST ports")


if __name__ == "__main__":
    main()
