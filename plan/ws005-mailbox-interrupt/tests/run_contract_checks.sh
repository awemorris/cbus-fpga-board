#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
temp_dir="$root/plan/ws005-mailbox-interrupt/temp/contract"

mkdir -p "$temp_dir"

python3 "$root/plan/ws005-mailbox-interrupt/tests/generate_mailbox_constants.py"

iverilog -g2012 -Wall -Wimplicit \
    -s tb_mailbox_constants \
    -o "$temp_dir/tb_mailbox_constants.vvp" \
    "$root/rtl/include/cbus_mailbox_regs_pkg.sv" \
    "$root/plan/ws005-mailbox-interrupt/tests/tb_mailbox_constants.sv"
vvp "$temp_dir/tb_mailbox_constants.vvp"

cc -std=c11 -Wall -Wextra -Werror \
    -I "$root/sw/include" \
    "$root/plan/ws005-mailbox-interrupt/tests/test_mailbox_constants.c" \
    -o "$temp_dir/test_mailbox_constants"
"$temp_dir/test_mailbox_constants"
echo "test_mailbox_constants: PASS: 12 compile-time checks"
