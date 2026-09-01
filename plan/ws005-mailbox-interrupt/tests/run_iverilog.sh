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
