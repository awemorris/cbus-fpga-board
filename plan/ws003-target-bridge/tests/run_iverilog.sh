#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
build_dir="$repo_root/plan/ws003-target-bridge/temp/iverilog"

mkdir -p "$build_dir"

compile_and_run() {
    top="$1"
    shift

    iverilog \
        -g2012 \
        -Wall \
        -Wimplicit \
        -s "$top" \
        -o "$build_dir/$top.vvp" \
        "$@"

    (
        cd "$build_dir"
        vvp "./$top.vvp"
    )
}

compile_and_run tb_cbus_target_mvp \
    "$repo_root/rtl/cbus/cbus_target_engine.sv" \
    "$repo_root/rtl/cbus/cbus_target_regs.sv" \
    "$repo_root/plan/ws003-target-bridge/tests/tb_cbus_target_mvp.sv"

compile_and_run tb_async_fifo \
    "$repo_root/rtl/common/async_fifo.sv" \
    "$repo_root/plan/ws003-target-bridge/tests/tb_async_fifo.sv"

compile_and_run tb_cbus_axil_bridge \
    "$repo_root/rtl/common/reset_sync.sv" \
    "$repo_root/rtl/common/async_fifo.sv" \
    "$repo_root/rtl/cbus/cbus_target_engine.sv" \
    "$repo_root/rtl/cbus/cbus_req_rsp_cdc.sv" \
    "$repo_root/rtl/axi/cbus_to_axil_bridge.sv" \
    "$repo_root/rtl/cbus/cbus_target_axil_subsystem.sv" \
    "$repo_root/plan/ws003-target-bridge/tests/tb_cbus_axil_bridge.sv"

compile_and_run tb_axil_guard_timeout \
    "$repo_root/rtl/axi/axil_guard_timeout.sv" \
    "$repo_root/plan/ws003-target-bridge/tests/tb_axil_guard_timeout.sv"

compile_and_run tb_cbus_guarded_axil \
    "$repo_root/rtl/common/reset_sync.sv" \
    "$repo_root/rtl/common/async_fifo.sv" \
    "$repo_root/rtl/cbus/cbus_target_engine.sv" \
    "$repo_root/rtl/cbus/cbus_req_rsp_cdc.sv" \
    "$repo_root/rtl/axi/cbus_to_axil_bridge.sv" \
    "$repo_root/rtl/cbus/cbus_target_axil_subsystem.sv" \
    "$repo_root/rtl/axi/axil_guard_timeout.sv" \
    "$repo_root/rtl/cbus/cbus_target_guarded_axil_subsystem.sv" \
    "$repo_root/plan/ws003-target-bridge/tests/tb_cbus_guarded_axil.sv"
