#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
build_dir="$repo_root/plan/ws003-target-bridge/temp/iverilog"

mkdir -p "$build_dir"

iverilog \
    -g2012 \
    -Wall \
    -Wimplicit \
    -s tb_cbus_target_mvp \
    -o "$build_dir/tb_cbus_target_mvp.vvp" \
    "$repo_root/rtl/cbus/cbus_target_engine.sv" \
    "$repo_root/rtl/cbus/cbus_target_regs.sv" \
    "$repo_root/plan/ws003-target-bridge/tests/tb_cbus_target_mvp.sv"

(
    cd "$build_dir"
    vvp ./tb_cbus_target_mvp.vvp
)
