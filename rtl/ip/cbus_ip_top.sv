`timescale 1ns/1ps
`default_nettype none

// Board-independent C-bus IP boundary.  Physical pins, constraints, clock
// primitives, memory devices and final safety gating belong above this module.
module cbus_ip_top #(
    parameter logic [15:0] IO_BASE_ADDR = 16'h00d0,
    parameter logic [15:0] IO_ADDR_MASK = 16'hfff8,
    parameter logic [31:0] AXIL_BASE_ADDR = 32'h1000_0000,
    parameter logic [31:0] AXIL_ALLOW_BASE_ADDR = 32'h1000_0000,
    parameter logic [31:0] AXIL_ALLOW_ADDR_MASK = 32'hffff_f000,
    parameter integer WAIT_ASSERT_CYCLES = 4,
    parameter integer CBUS_TIMEOUT_CYCLES = 600,
    parameter integer AXIL_TIMEOUT_CYCLES = 256,
    parameter integer RELEASE_HOLD_CYCLES = 1,
    parameter integer TAG_WIDTH = 8,
    parameter integer FIFO_ADDR_WIDTH = 2
) (
    input  logic        cbus_logic_clk,
    input  logic        axi_clk,
    input  logic        rst_n,
    input  logic        platform_ready,
    input  logic        guard_status_clear,
    input  logic        guard_fault_clear,

    input  logic [23:0] cbus_ab_i,
    output logic [23:0] cbus_ab_o,
    output logic        cbus_ab_oe_req,
    input  logic [15:0] cbus_db_i,
    output logic [15:0] cbus_db_o,
    output logic        cbus_db_oe_req,

    input  logic cbus_ior_n_i,
    output logic cbus_ior_n_o,
    output logic cbus_ior_n_oe_req,
    input  logic cbus_iow_n_i,
    output logic cbus_iow_n_o,
    output logic cbus_iow_n_oe_req,
    input  logic cbus_mrc_n_i,
    output logic cbus_mrc_n_o,
    output logic cbus_mrc_n_oe_req,
    input  logic cbus_mwc_n_i,
    output logic cbus_mwc_n_o,
    output logic cbus_mwc_n_oe_req,
    input  logic cbus_mwe_n_i,
    output logic cbus_mwe_n_o,
    output logic cbus_mwe_n_oe_req,
    input  logic cbus_bhe_n_i,
    output logic cbus_bhe_n_o,
    output logic cbus_bhe_n_oe_req,
    input  logic cbus_reset_n_i,
    input  logic cbus_power_n_i,
    input  logic cbus_sclk_i,

    output logic cbus_iordy_o,
    output logic cbus_iordy_oe_req,
    output logic cbus_irq_assert,
    input  logic cbus_dack_n_i,
    output logic cbus_drq_n_assert,
    output logic cbus_word_n_o,
    output logic cbus_word_oe_req,
    input  logic cbus_dmatc_n_i,
    output logic cbus_exhrq1_n_assert,
    output logic cbus_exhrq2_n_assert,
    input  logic cbus_exhla1_n_i,
    input  logic cbus_exhla2_n_i,
    input  logic cbus_sbusrq_i,

    output logic lvc_data_dir_req,
    output logic lvc_data_oe_req,
    output logic lvc_iordy_oe_req,
    output logic lvc_irq_oe_req,
    output logic lvc_word_oe_req,
    output logic lvc_addr_dir_req,
    output logic lvc_addr_oe_req,
    output logic lvc_cmd_dir_req,
    output logic lvc_cmd_oe_req,

    output logic        busy,
    output logic        timeout_sticky,
    output logic        invalid_sticky,
    output logic        backend_error_sticky,
    output logic        abort_sticky,
    output logic        stale_rsp_pulse,
    output logic        guard_faulted,
    output logic        guard_fault_reset_req,
    output logic        guard_reject_sticky,
    output logic        guard_timeout_sticky,
    output logic        guard_downstream_error_sticky,
    output logic        guard_fault_valid,
    output logic [2:0]  guard_fault_code,
    output logic        guard_fault_write,
    output logic [31:0] guard_fault_addr,

    output logic [31:0] m_axil_awaddr,
    output logic [2:0]  m_axil_awprot,
    output logic        m_axil_awvalid,
    input  logic        m_axil_awready,
    output logic [31:0] m_axil_wdata,
    output logic [3:0]  m_axil_wstrb,
    output logic        m_axil_wvalid,
    input  logic        m_axil_wready,
    input  logic [1:0]  m_axil_bresp,
    input  logic        m_axil_bvalid,
    output logic        m_axil_bready,
    output logic [31:0] m_axil_araddr,
    output logic [2:0]  m_axil_arprot,
    output logic        m_axil_arvalid,
    input  logic        m_axil_arready,
    input  logic [31:0] m_axil_rdata,
    input  logic [1:0]  m_axil_rresp,
    input  logic        m_axil_rvalid,
    output logic        m_axil_rready
);

    // The 69-pin boundary reserves future memory, DMA and 286+ bus-master
    // paths.  The present passive I/O-target build keeps every such drive
    // request inactive while retaining the ports and ABI.
    always_comb begin
        cbus_ab_o = 24'h000000;
        cbus_ab_oe_req = 1'b0;
        cbus_ior_n_o = 1'b1;
        cbus_ior_n_oe_req = 1'b0;
        cbus_iow_n_o = 1'b1;
        cbus_iow_n_oe_req = 1'b0;
        cbus_mrc_n_o = 1'b1;
        cbus_mrc_n_oe_req = 1'b0;
        cbus_mwc_n_o = 1'b1;
        cbus_mwc_n_oe_req = 1'b0;
        cbus_mwe_n_o = 1'b1;
        cbus_mwe_n_oe_req = 1'b0;
        cbus_bhe_n_o = 1'b1;
        cbus_bhe_n_oe_req = 1'b0;

        cbus_iordy_o = 1'b0;
        cbus_irq_assert = 1'b0;
        cbus_drq_n_assert = 1'b0;
        cbus_word_n_o = 1'b0;
        cbus_word_oe_req = 1'b0;
        cbus_exhrq1_n_assert = 1'b0;
        cbus_exhrq2_n_assert = 1'b0;

        lvc_data_dir_req = cbus_db_oe_req;
        lvc_data_oe_req = cbus_db_oe_req;
        lvc_iordy_oe_req = cbus_iordy_oe_req;
        lvc_irq_oe_req = 1'b0;
        lvc_word_oe_req = 1'b0;
        lvc_addr_dir_req = 1'b0;
        lvc_addr_oe_req = 1'b0;
        lvc_cmd_dir_req = 1'b0;
        lvc_cmd_oe_req = 1'b0;
    end

    // Reserved inputs are deliberately present at the stable boundary.  They
    // become live only in separately authorized memory/DMA/master phases.
    wire reserved_inputs_known =
        cbus_mrc_n_i ^ cbus_mwc_n_i ^ cbus_mwe_n_i ^ cbus_reset_n_i ^
        cbus_power_n_i ^ cbus_sclk_i ^ cbus_dack_n_i ^ cbus_dmatc_n_i ^
        cbus_exhla1_n_i ^ cbus_exhla2_n_i ^ cbus_sbusrq_i;

    cbus_target_guarded_axil_subsystem #(
        .IO_BASE_ADDR(IO_BASE_ADDR),
        .IO_ADDR_MASK(IO_ADDR_MASK),
        .AXIL_BASE_ADDR(AXIL_BASE_ADDR),
        .AXIL_ALLOW_BASE_ADDR(AXIL_ALLOW_BASE_ADDR),
        .AXIL_ALLOW_ADDR_MASK(AXIL_ALLOW_ADDR_MASK),
        .WAIT_ASSERT_CYCLES(WAIT_ASSERT_CYCLES),
        .CBUS_TIMEOUT_CYCLES(CBUS_TIMEOUT_CYCLES),
        .AXIL_TIMEOUT_CYCLES(AXIL_TIMEOUT_CYCLES),
        .RELEASE_HOLD_CYCLES(RELEASE_HOLD_CYCLES),
        .TAG_WIDTH(TAG_WIDTH),
        .FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) target (
        .c_clk(cbus_logic_clk),
        .a_clk(axi_clk),
        .rst_n(rst_n),
        .platform_ready(platform_ready),
        .guard_status_clear(guard_status_clear),
        .guard_fault_clear(guard_fault_clear),
        .cbus_addr_i(cbus_ab_i[15:0]),
        .cbus_data_i(cbus_db_i),
        .cbus_bhe_n_i(cbus_bhe_n_i),
        .cbus_ior_n_i(cbus_ior_n_i),
        .cbus_iow_n_i(cbus_iow_n_i),
        .cbus_data_o(cbus_db_o),
        .cbus_data_oe_req(cbus_db_oe_req),
        .cbus_iordy_oe_req(cbus_iordy_oe_req),
        .busy(busy),
        .timeout_sticky(timeout_sticky),
        .invalid_sticky(invalid_sticky),
        .backend_error_sticky(backend_error_sticky),
        .abort_sticky(abort_sticky),
        .stale_rsp_pulse(stale_rsp_pulse),
        .guard_faulted(guard_faulted),
        .guard_fault_reset_req(guard_fault_reset_req),
        .guard_reject_sticky(guard_reject_sticky),
        .guard_timeout_sticky(guard_timeout_sticky),
        .guard_downstream_error_sticky(guard_downstream_error_sticky),
        .guard_fault_valid(guard_fault_valid),
        .guard_fault_code(guard_fault_code),
        .guard_fault_write(guard_fault_write),
        .guard_fault_addr(guard_fault_addr),
        .m_axil_awaddr(m_axil_awaddr),
        .m_axil_awprot(m_axil_awprot),
        .m_axil_awvalid(m_axil_awvalid),
        .m_axil_awready(m_axil_awready),
        .m_axil_wdata(m_axil_wdata),
        .m_axil_wstrb(m_axil_wstrb),
        .m_axil_wvalid(m_axil_wvalid),
        .m_axil_wready(m_axil_wready),
        .m_axil_bresp(m_axil_bresp),
        .m_axil_bvalid(m_axil_bvalid),
        .m_axil_bready(m_axil_bready),
        .m_axil_araddr(m_axil_araddr),
        .m_axil_arprot(m_axil_arprot),
        .m_axil_arvalid(m_axil_arvalid),
        .m_axil_arready(m_axil_arready),
        .m_axil_rdata(m_axil_rdata),
        .m_axil_rresp(m_axil_rresp),
        .m_axil_rvalid(m_axil_rvalid),
        .m_axil_rready(m_axil_rready)
    );

    // Keep the reservation explicit without letting it affect implemented
    // behavior.  Synthesis will remove this zero-weight observation.
    wire unused_reserved_inputs = reserved_inputs_known;

endmodule

`default_nettype wire
