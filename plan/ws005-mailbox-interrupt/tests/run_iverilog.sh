#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
build_dir="$repo_root/plan/ws005-mailbox-interrupt/temp/iverilog"

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

compile_and_run tb_mailbox_sync_fifo \
    "$repo_root/rtl/ip/mailbox_sync_fifo.sv" \
    "$repo_root/plan/ws005-mailbox-interrupt/tests/tb_mailbox_sync_fifo.sv"

compile_and_run tb_mailbox_interrupt_subsystem \
    "$repo_root/rtl/include/cbus_mailbox_regs_pkg.sv" \
    "$repo_root/rtl/ip/mailbox_sync_fifo.sv" \
    "$repo_root/rtl/ip/axil_interrupt_router.sv" \
    "$repo_root/rtl/ip/axil_mailbox.sv" \
    "$repo_root/rtl/ip/mailbox_interrupt_subsystem.sv" \
    "$repo_root/plan/ws005-mailbox-interrupt/tests/tb_mailbox_interrupt_subsystem.sv"

compile_and_run tb_cbus_mailbox_alias_bridge \
    "$repo_root/rtl/include/cbus_mailbox_regs_pkg.sv" \
    "$repo_root/rtl/axi/cbus_to_axil_bridge.sv" \
    "$repo_root/plan/ws005-mailbox-interrupt/tests/tb_cbus_mailbox_alias_bridge.sv"

compile_and_run tb_axil_control_fabric_1x3 \
    "$repo_root/rtl/axi/axil_control_fabric_1x3.sv" \
    "$repo_root/plan/ws005-mailbox-interrupt/tests/tb_axil_control_fabric_1x3.sv"

compile_and_run tb_cbus_mailbox_alias_top \
    "$repo_root/rtl/include/cbus_mailbox_regs_pkg.sv" \
    "$repo_root/rtl/common/reset_sync.sv" \
    "$repo_root/rtl/common/async_fifo.sv" \
    "$repo_root/rtl/cbus/cbus_target_engine.sv" \
    "$repo_root/rtl/cbus/cbus_req_rsp_cdc.sv" \
    "$repo_root/rtl/axi/cbus_to_axil_bridge.sv" \
    "$repo_root/rtl/cbus/cbus_target_axil_subsystem.sv" \
    "$repo_root/rtl/axi/axil_guard_timeout.sv" \
    "$repo_root/rtl/cbus/cbus_target_guarded_axil_subsystem.sv" \
    "$repo_root/rtl/axi/axil_control_fabric_1x3.sv" \
    "$repo_root/rtl/ip/axil_system_csr.sv" \
    "$repo_root/rtl/ip/mailbox_sync_fifo.sv" \
    "$repo_root/rtl/ip/axil_interrupt_router.sv" \
    "$repo_root/rtl/ip/axil_mailbox.sv" \
    "$repo_root/rtl/ip/mailbox_interrupt_subsystem.sv" \
    "$repo_root/rtl/ip/cbus_control_subsystem.sv" \
    "$repo_root/rtl/ip/cbus_ip_top.sv" \
    "$repo_root/plan/ws005-mailbox-interrupt/tests/tb_cbus_mailbox_alias_top.sv"
