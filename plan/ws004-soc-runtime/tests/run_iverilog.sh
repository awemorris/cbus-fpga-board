#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
build_dir="$repo_root/plan/ws004-soc-runtime/temp/iverilog"

mkdir -p "$build_dir"

iverilog \
    -g2012 \
    -Wall \
    -Wimplicit \
    -s tb_riscv_core_ip_stub \
    -o "$build_dir/tb_riscv_core_ip_stub.vvp" \
    "$repo_root/rtl/cpu/riscv_core_ip_stub.sv" \
    "$repo_root/plan/ws004-soc-runtime/tests/tb_riscv_core_ip_stub.sv"

(
    cd "$build_dir"
    vvp ./tb_riscv_core_ip_stub.vvp
)

python3 "$repo_root/plan/ws004-soc-runtime/tests/validate_riscv_core_interface.py"
