`timescale 1ns/1ps
`default_nettype none

// Testable board shell shared by the Primer and Mega wrappers.  The wrapper
// supplies clocks and independently established platform-safety status.
module cbus_board_shell #(
    parameter logic [15:0] IO_BASE_ADDR = 16'h00d0,
    parameter logic [15:0] IO_ADDR_MASK = 16'hfff8,
    parameter bit          CBUS_MBX_ENABLE = 1'b0,
    parameter logic [15:0] CBUS_MBX_IO_BASE = 16'h0000,
    parameter integer WAIT_ASSERT_CYCLES = 4,
    parameter integer CBUS_TIMEOUT_CYCLES = 600,
    parameter integer AXIL_TIMEOUT_CYCLES = 256
) (
    input  logic cbus_logic_clk,
    input  logic axi_clk,
    input  logic power_good,
    input  logic config_done,
    input  logic clock_locked,
    input  logic reset_released,
    input  logic external_safety_latch,
    input  logic bus_permit,

    inout  wire [23:0] cbus_ab,
    inout  wire [15:0] cbus_db,
    inout  wire cbus_ior_n,
    inout  wire cbus_iow_n,
    inout  wire cbus_mrc_n,
    inout  wire cbus_mwc_n,
    inout  wire cbus_mwe_n,
    inout  wire cbus_bhe_n,
    input  logic cbus_reset_n,
    input  logic cbus_power_n,
    input  logic cbus_sclk,
    output logic cbus_iordy,
    output logic cbus_irq_selected,
    input  logic cbus_dack_selected_n,
    output logic cbus_drq_selected_n,
    output logic cbus_word_n,
    input  logic cbus_dmatc_n,
    output logic cbus_b40_exhrq1_n,
    output logic cbus_b47_exhrq2_n,
    input  logic cbus_b42_exhla1_n,
    input  logic cbus_b46_exhla2_n,
    input  logic cbus_b48_sbusrq,

    output logic lvc_data_dir,
    output logic lvc_data_oe_n,
    output logic lvc_iordy_oe_n,
    output logic lvc_irq_oe_n,
    output logic lvc_word_oe_n,
    output logic lvc_addr_dir,
    output logic lvc_addr_oe_n,
    output logic lvc_cmd_dir,
    output logic lvc_cmd_oe_n
);

    logic [23:0] ab_o;
    logic [15:0] db_o;
    logic ab_oe_req;
    logic db_oe_req;
    logic ior_n_o, ior_n_oe_req;
    logic iow_n_o, iow_n_oe_req;
    logic mrc_n_o, mrc_n_oe_req;
    logic mwc_n_o, mwc_n_oe_req;
    logic mwe_n_o, mwe_n_oe_req;
    logic bhe_n_o, bhe_n_oe_req;
    logic iordy_o, iordy_oe_req;
    logic irq_assert;
    logic drq_assert;
    logic word_n_o, word_oe_req;
    logic exhrq1_assert, exhrq2_assert;
    logic data_dir_req, data_oe_req;
    logic safe_iordy_oe_req, irq_oe_req, safe_word_oe_req;
    logic addr_dir_req, addr_oe_req, cmd_dir_req, cmd_oe_req;
    logic drive_permit;
    logic data_pad_oe, addr_pad_oe, cmd_pad_oe;
    logic platform_ready;
    logic rst_n;

    assign rst_n = reset_released && cbus_reset_n;
    assign platform_ready = drive_permit;

    assign cbus_ab = addr_pad_oe ? ab_o : 24'hzzzzzz;
    assign cbus_db = data_pad_oe ? db_o : 16'hzzzz;
    assign cbus_ior_n = cmd_pad_oe && ior_n_oe_req ? ior_n_o : 1'bz;
    assign cbus_iow_n = cmd_pad_oe && iow_n_oe_req ? iow_n_o : 1'bz;
    assign cbus_mrc_n = cmd_pad_oe && mrc_n_oe_req ? mrc_n_o : 1'bz;
    assign cbus_mwc_n = cmd_pad_oe && mwc_n_oe_req ? mwc_n_o : 1'bz;
    assign cbus_mwe_n = cmd_pad_oe && mwe_n_oe_req ? mwe_n_o : 1'bz;
    assign cbus_bhe_n = cmd_pad_oe && bhe_n_oe_req ? bhe_n_o : 1'bz;

    always_comb begin
        cbus_iordy = iordy_o;
        cbus_irq_selected = drive_permit ? irq_assert : 1'b0;
        cbus_drq_selected_n = drive_permit ? drq_assert : 1'b0;
        cbus_word_n = drive_permit ? word_n_o : 1'b0;
        cbus_b40_exhrq1_n = drive_permit ? exhrq1_assert : 1'b0;
        cbus_b47_exhrq2_n = drive_permit ? exhrq2_assert : 1'b0;
    end

    cbus_pad_adapter pad_safety (
        .power_good(power_good),
        .config_done(config_done),
        .clock_locked(clock_locked),
        .reset_released(reset_released && cbus_reset_n),
        .external_safety_latch(external_safety_latch),
        .bus_permit(bus_permit),
        .data_dir_req(data_dir_req),
        .data_oe_req(data_oe_req),
        .iordy_oe_req(safe_iordy_oe_req),
        .irq_oe_req(irq_oe_req),
        .word_oe_req(safe_word_oe_req),
        .addr_dir_req(addr_dir_req),
        .addr_oe_req(addr_oe_req),
        .cmd_dir_req(cmd_dir_req),
        .cmd_oe_req(cmd_oe_req),
        .drive_permit_o(drive_permit),
        .data_pad_oe(data_pad_oe),
        .addr_pad_oe(addr_pad_oe),
        .cmd_pad_oe(cmd_pad_oe),
        .data_dir(lvc_data_dir),
        .data_oe_n(lvc_data_oe_n),
        .iordy_oe_n(lvc_iordy_oe_n),
        .irq_oe_n(lvc_irq_oe_n),
        .word_oe_n(lvc_word_oe_n),
        .addr_dir(lvc_addr_dir),
        .addr_oe_n(lvc_addr_oe_n),
        .cmd_dir(lvc_cmd_dir),
        .cmd_oe_n(lvc_cmd_oe_n)
    );

    cbus_ip_top #(
        .IO_BASE_ADDR(IO_BASE_ADDR),
        .IO_ADDR_MASK(IO_ADDR_MASK),
        .CBUS_MBX_ENABLE(CBUS_MBX_ENABLE),
        .CBUS_MBX_IO_BASE(CBUS_MBX_IO_BASE),
        .WAIT_ASSERT_CYCLES(WAIT_ASSERT_CYCLES),
        .CBUS_TIMEOUT_CYCLES(CBUS_TIMEOUT_CYCLES),
        .AXIL_TIMEOUT_CYCLES(AXIL_TIMEOUT_CYCLES)
    ) ip (
        .cbus_logic_clk(cbus_logic_clk), .axi_clk(axi_clk),
        .rst_n(rst_n), .platform_ready(platform_ready),
        .guard_status_clear(1'b0), .guard_fault_clear(1'b0),
        .cbus_ab_i(cbus_ab), .cbus_ab_o(ab_o), .cbus_ab_oe_req(ab_oe_req),
        .cbus_db_i(cbus_db), .cbus_db_o(db_o), .cbus_db_oe_req(db_oe_req),
        .cbus_ior_n_i(cbus_ior_n), .cbus_ior_n_o(ior_n_o), .cbus_ior_n_oe_req(ior_n_oe_req),
        .cbus_iow_n_i(cbus_iow_n), .cbus_iow_n_o(iow_n_o), .cbus_iow_n_oe_req(iow_n_oe_req),
        .cbus_mrc_n_i(cbus_mrc_n), .cbus_mrc_n_o(mrc_n_o), .cbus_mrc_n_oe_req(mrc_n_oe_req),
        .cbus_mwc_n_i(cbus_mwc_n), .cbus_mwc_n_o(mwc_n_o), .cbus_mwc_n_oe_req(mwc_n_oe_req),
        .cbus_mwe_n_i(cbus_mwe_n), .cbus_mwe_n_o(mwe_n_o), .cbus_mwe_n_oe_req(mwe_n_oe_req),
        .cbus_bhe_n_i(cbus_bhe_n), .cbus_bhe_n_o(bhe_n_o), .cbus_bhe_n_oe_req(bhe_n_oe_req),
        .cbus_reset_n_i(cbus_reset_n), .cbus_power_n_i(cbus_power_n), .cbus_sclk_i(cbus_sclk),
        .cbus_iordy_o(iordy_o), .cbus_iordy_oe_req(iordy_oe_req),
        .cbus_irq_assert(irq_assert), .cbus_dack_n_i(cbus_dack_selected_n),
        .cbus_drq_n_assert(drq_assert), .cbus_word_n_o(word_n_o), .cbus_word_oe_req(word_oe_req),
        .cbus_dmatc_n_i(cbus_dmatc_n), .cbus_exhrq1_n_assert(exhrq1_assert),
        .cbus_exhrq2_n_assert(exhrq2_assert), .cbus_exhla1_n_i(cbus_b42_exhla1_n),
        .cbus_exhla2_n_i(cbus_b46_exhla2_n), .cbus_sbusrq_i(cbus_b48_sbusrq),
        .lvc_data_dir_req(data_dir_req), .lvc_data_oe_req(data_oe_req),
        .lvc_iordy_oe_req(safe_iordy_oe_req), .lvc_irq_oe_req(irq_oe_req),
        .lvc_word_oe_req(safe_word_oe_req), .lvc_addr_dir_req(addr_dir_req),
        .lvc_addr_oe_req(addr_oe_req), .lvc_cmd_dir_req(cmd_dir_req), .lvc_cmd_oe_req(cmd_oe_req),
        .busy(), .timeout_sticky(), .invalid_sticky(), .backend_error_sticky(),
        .abort_sticky(), .stale_rsp_pulse(), .guard_faulted(), .guard_fault_reset_req(),
        .guard_reject_sticky(), .guard_timeout_sticky(), .guard_downstream_error_sticky(),
        .guard_fault_valid(), .guard_fault_code(), .guard_fault_write(), .guard_fault_addr(),
        .mailbox_cpu_irq_active(), .mailbox_host_irq_active()
    );

endmodule

`default_nettype wire
