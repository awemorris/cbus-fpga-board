`timescale 1ns/1ps
`default_nettype none

module cbus_target_guarded_axil_subsystem #(
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
    input  logic        c_clk,
    input  logic        a_clk,
    input  logic        rst_n,
    input  logic        platform_ready,
    input  logic        guard_status_clear,
    input  logic        guard_fault_clear,

    input  logic [15:0] cbus_addr_i,
    input  logic [15:0] cbus_data_i,
    input  logic        cbus_bhe_n_i,
    input  logic        cbus_ior_n_i,
    input  logic        cbus_iow_n_i,

    output logic [15:0] cbus_data_o,
    output logic        cbus_data_oe_req,
    output logic        cbus_iordy_oe_req,

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

    logic a_rst_n;
    logic [31:0] u_awaddr;
    logic [2:0] u_awprot;
    logic u_awvalid;
    logic u_awready;
    logic [31:0] u_wdata;
    logic [3:0] u_wstrb;
    logic u_wvalid;
    logic u_wready;
    logic [1:0] u_bresp;
    logic u_bvalid;
    logic u_bready;
    logic [31:0] u_araddr;
    logic [2:0] u_arprot;
    logic u_arvalid;
    logic u_arready;
    logic [31:0] u_rdata;
    logic [1:0] u_rresp;
    logic u_rvalid;
    logic u_rready;

    reset_sync guard_reset_sync (
        .clk(a_clk),
        .async_rst_n(rst_n),
        .sync_rst_n(a_rst_n)
    );

    cbus_target_axil_subsystem #(
        .IO_BASE_ADDR(IO_BASE_ADDR),
        .IO_ADDR_MASK(IO_ADDR_MASK),
        .AXIL_BASE_ADDR(AXIL_BASE_ADDR),
        .WAIT_ASSERT_CYCLES(WAIT_ASSERT_CYCLES),
        .TIMEOUT_CYCLES(CBUS_TIMEOUT_CYCLES),
        .RELEASE_HOLD_CYCLES(RELEASE_HOLD_CYCLES),
        .TAG_WIDTH(TAG_WIDTH),
        .FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) target_subsystem (
        .c_clk(c_clk),
        .a_clk(a_clk),
        .rst_n(rst_n),
        .platform_ready(platform_ready),
        .cbus_addr_i(cbus_addr_i),
        .cbus_data_i(cbus_data_i),
        .cbus_bhe_n_i(cbus_bhe_n_i),
        .cbus_ior_n_i(cbus_ior_n_i),
        .cbus_iow_n_i(cbus_iow_n_i),
        .cbus_data_o(cbus_data_o),
        .cbus_data_oe_req(cbus_data_oe_req),
        .cbus_iordy_oe_req(cbus_iordy_oe_req),
        .busy(busy),
        .timeout_sticky(timeout_sticky),
        .invalid_sticky(invalid_sticky),
        .backend_error_sticky(backend_error_sticky),
        .abort_sticky(abort_sticky),
        .stale_rsp_pulse(stale_rsp_pulse),
        .m_axil_awaddr(u_awaddr),
        .m_axil_awprot(u_awprot),
        .m_axil_awvalid(u_awvalid),
        .m_axil_awready(u_awready),
        .m_axil_wdata(u_wdata),
        .m_axil_wstrb(u_wstrb),
        .m_axil_wvalid(u_wvalid),
        .m_axil_wready(u_wready),
        .m_axil_bresp(u_bresp),
        .m_axil_bvalid(u_bvalid),
        .m_axil_bready(u_bready),
        .m_axil_araddr(u_araddr),
        .m_axil_arprot(u_arprot),
        .m_axil_arvalid(u_arvalid),
        .m_axil_arready(u_arready),
        .m_axil_rdata(u_rdata),
        .m_axil_rresp(u_rresp),
        .m_axil_rvalid(u_rvalid),
        .m_axil_rready(u_rready)
    );

    axil_guard_timeout #(
        .ALLOW_BASE_ADDR(AXIL_ALLOW_BASE_ADDR),
        .ALLOW_ADDR_MASK(AXIL_ALLOW_ADDR_MASK),
        .TIMEOUT_CYCLES(AXIL_TIMEOUT_CYCLES)
    ) guard (
        .clk(a_clk),
        .rst_n(a_rst_n),
        .status_clear(guard_status_clear),
        .fault_clear(guard_fault_clear),
        .faulted(guard_faulted),
        .fault_reset_req(guard_fault_reset_req),
        .guard_sticky(guard_reject_sticky),
        .timeout_sticky(guard_timeout_sticky),
        .downstream_error_sticky(guard_downstream_error_sticky),
        .fault_valid(guard_fault_valid),
        .fault_code(guard_fault_code),
        .fault_write(guard_fault_write),
        .fault_addr(guard_fault_addr),
        .s_axil_awaddr(u_awaddr),
        .s_axil_awprot(u_awprot),
        .s_axil_awvalid(u_awvalid),
        .s_axil_awready(u_awready),
        .s_axil_wdata(u_wdata),
        .s_axil_wstrb(u_wstrb),
        .s_axil_wvalid(u_wvalid),
        .s_axil_wready(u_wready),
        .s_axil_bresp(u_bresp),
        .s_axil_bvalid(u_bvalid),
        .s_axil_bready(u_bready),
        .s_axil_araddr(u_araddr),
        .s_axil_arprot(u_arprot),
        .s_axil_arvalid(u_arvalid),
        .s_axil_arready(u_arready),
        .s_axil_rdata(u_rdata),
        .s_axil_rresp(u_rresp),
        .s_axil_rvalid(u_rvalid),
        .s_axil_rready(u_rready),
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

endmodule

`default_nettype wire
