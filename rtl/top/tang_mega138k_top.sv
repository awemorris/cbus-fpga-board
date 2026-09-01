`timescale 1ns/1ps
`default_nettype none

module tang_mega138k_top #(
    // Zero is the only production-safe default until a Gowin clock/config
    // status wrapper and carrier safety latch replace this raw-clock shell.
    parameter bit ENABLE_RAW_CLOCK_TEST_ONLY = 1'b0,
    parameter bit CBUS_MBX_ENABLE = 1'b0,
    parameter logic [15:0] CBUS_MBX_IO_BASE = 16'h0000,
    parameter bit CBUS_MEM_ENABLE = 1'b0,
    parameter logic [23:0] CBUS_MEM_BASE = 24'h000000,
    parameter logic [23:0] CBUS_MEM_ADDR_MASK = 24'hffffff,
    parameter logic [31:0] AXIL_MEM_TARGET_BASE = 32'h1000_0800
) (
    input  logic board_clk,
    inout  wire [23:0] cbus_ab,
    inout  wire [15:0] cbus_db,
    inout  wire cbus_ior_n, cbus_iow_n, cbus_mrc_n, cbus_mwc_n, cbus_mwe_n, cbus_bhe_n,
    input  logic cbus_reset_n, cbus_power_n, cbus_sclk,
    output logic cbus_iordy, cbus_irq_selected,
    input  logic cbus_dack_selected_n,
    output logic cbus_drq_selected_n, cbus_word_n,
    input  logic cbus_dmatc_n,
    output logic cbus_b40_exhrq1_n, cbus_b47_exhrq2_n,
    input  logic cbus_b42_exhla1_n, cbus_b46_exhla2_n, cbus_b48_sbusrq,
    output logic lvc_data_dir, lvc_data_oe_n, lvc_iordy_oe_n, lvc_irq_oe_n,
    output logic lvc_word_oe_n, lvc_addr_dir, lvc_addr_oe_n, lvc_cmd_dir, lvc_cmd_oe_n
);

    wire test_enable = ENABLE_RAW_CLOCK_TEST_ONLY;

    cbus_board_shell #(
        .CBUS_MBX_ENABLE(CBUS_MBX_ENABLE),
        .CBUS_MBX_IO_BASE(CBUS_MBX_IO_BASE),
        .CBUS_MEM_ENABLE(CBUS_MEM_ENABLE),
        .CBUS_MEM_BASE(CBUS_MEM_BASE),
        .CBUS_MEM_ADDR_MASK(CBUS_MEM_ADDR_MASK),
        .AXIL_MEM_TARGET_BASE(AXIL_MEM_TARGET_BASE)
    ) shell (
        .cbus_logic_clk(board_clk), .axi_clk(board_clk),
        .power_good(cbus_power_n), .config_done(test_enable),
        .clock_locked(test_enable), .reset_released(cbus_reset_n),
        .external_safety_latch(test_enable), .bus_permit(test_enable),
        .cbus_ab(cbus_ab), .cbus_db(cbus_db),
        .cbus_ior_n(cbus_ior_n), .cbus_iow_n(cbus_iow_n),
        .cbus_mrc_n(cbus_mrc_n), .cbus_mwc_n(cbus_mwc_n),
        .cbus_mwe_n(cbus_mwe_n), .cbus_bhe_n(cbus_bhe_n),
        .cbus_reset_n(cbus_reset_n), .cbus_power_n(cbus_power_n), .cbus_sclk(cbus_sclk),
        .cbus_iordy(cbus_iordy), .cbus_irq_selected(cbus_irq_selected),
        .cbus_dack_selected_n(cbus_dack_selected_n), .cbus_drq_selected_n(cbus_drq_selected_n),
        .cbus_word_n(cbus_word_n), .cbus_dmatc_n(cbus_dmatc_n),
        .cbus_b40_exhrq1_n(cbus_b40_exhrq1_n), .cbus_b47_exhrq2_n(cbus_b47_exhrq2_n),
        .cbus_b42_exhla1_n(cbus_b42_exhla1_n), .cbus_b46_exhla2_n(cbus_b46_exhla2_n),
        .cbus_b48_sbusrq(cbus_b48_sbusrq),
        .lvc_data_dir(lvc_data_dir), .lvc_data_oe_n(lvc_data_oe_n),
        .lvc_iordy_oe_n(lvc_iordy_oe_n), .lvc_irq_oe_n(lvc_irq_oe_n),
        .lvc_word_oe_n(lvc_word_oe_n), .lvc_addr_dir(lvc_addr_dir),
        .lvc_addr_oe_n(lvc_addr_oe_n), .lvc_cmd_dir(lvc_cmd_dir), .lvc_cmd_oe_n(lvc_cmd_oe_n)
    );

endmodule

`default_nettype wire
