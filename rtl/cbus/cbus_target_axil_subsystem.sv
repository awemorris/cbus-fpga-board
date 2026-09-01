`timescale 1ns/1ps
`default_nettype none

module cbus_target_axil_subsystem #(
    parameter logic [15:0] IO_BASE_ADDR = 16'h00d0,
    parameter logic [15:0] IO_ADDR_MASK = 16'hfff8,
    parameter bit          CBUS_MBX_ENABLE = 1'b0,
    parameter logic [15:0] CBUS_MBX_IO_BASE = 16'h0000,
    parameter logic [31:0] AXIL_BASE_ADDR = 32'h1000_0000,
    parameter integer WAIT_ASSERT_CYCLES = 4,
    parameter integer TIMEOUT_CYCLES = 600,
    parameter integer RELEASE_HOLD_CYCLES = 1,
    parameter integer TAG_WIDTH = 8,
    parameter integer FIFO_ADDR_WIDTH = 2
) (
    input  logic        c_clk,
    input  logic        a_clk,
    input  logic        rst_n,
    input  logic        platform_ready,

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

    logic req_valid;
    logic req_ready;
    logic req_write;
    logic [15:0] req_addr;
    logic [15:0] req_wdata;
    logic [1:0] req_be;
    logic rsp_valid;
    logic [15:0] rsp_rdata;
    logic rsp_error;

    logic a_req_valid;
    logic a_req_ready;
    logic [TAG_WIDTH-1:0] a_req_tag;
    logic a_req_write;
    logic [15:0] a_req_addr;
    logic [15:0] a_req_wdata;
    logic [1:0] a_req_be;
    logic a_rsp_valid;
    logic a_rsp_ready;
    logic [TAG_WIDTH-1:0] a_rsp_tag;
    logic [15:0] a_rsp_rdata;
    logic a_rsp_error;
    logic c_rst_n;
    logic a_rst_n;

    reset_sync c_reset_sync (
        .clk(c_clk),
        .async_rst_n(rst_n),
        .sync_rst_n(c_rst_n)
    );

    reset_sync a_reset_sync (
        .clk(a_clk),
        .async_rst_n(rst_n),
        .sync_rst_n(a_rst_n)
    );

    cbus_target_engine #(
        .IO_BASE_ADDR(IO_BASE_ADDR),
        .IO_ADDR_MASK(IO_ADDR_MASK),
        .CBUS_MBX_ENABLE(CBUS_MBX_ENABLE),
        .CBUS_MBX_IO_BASE(CBUS_MBX_IO_BASE),
        .WAIT_ASSERT_CYCLES(WAIT_ASSERT_CYCLES),
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES),
        .RELEASE_HOLD_CYCLES(RELEASE_HOLD_CYCLES)
    ) target_engine (
        .clk(c_clk),
        .rst_n(c_rst_n),
        .platform_ready(platform_ready),
        .cbus_addr_i(cbus_addr_i),
        .cbus_data_i(cbus_data_i),
        .cbus_bhe_n_i(cbus_bhe_n_i),
        .cbus_ior_n_i(cbus_ior_n_i),
        .cbus_iow_n_i(cbus_iow_n_i),
        .cbus_data_o(cbus_data_o),
        .cbus_data_oe_req(cbus_data_oe_req),
        .cbus_iordy_oe_req(cbus_iordy_oe_req),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_be(req_be),
        .rsp_valid(rsp_valid),
        .rsp_rdata(rsp_rdata),
        .rsp_error(rsp_error),
        .busy(busy),
        .timeout_sticky(timeout_sticky),
        .invalid_sticky(invalid_sticky),
        .backend_error_sticky(backend_error_sticky),
        .abort_sticky(abort_sticky)
    );

    cbus_req_rsp_cdc #(
        .TAG_WIDTH(TAG_WIDTH),
        .FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) req_rsp_cdc (
        .c_clk(c_clk),
        .c_rst_n(c_rst_n),
        .c_req_valid(req_valid),
        .c_req_ready(req_ready),
        .c_req_write(req_write),
        .c_req_addr(req_addr),
        .c_req_wdata(req_wdata),
        .c_req_be(req_be),
        .c_rsp_valid(rsp_valid),
        .c_rsp_rdata(rsp_rdata),
        .c_rsp_error(rsp_error),
        .c_stale_rsp_pulse(stale_rsp_pulse),
        .a_clk(a_clk),
        .a_rst_n(a_rst_n),
        .a_req_valid(a_req_valid),
        .a_req_ready(a_req_ready),
        .a_req_tag(a_req_tag),
        .a_req_write(a_req_write),
        .a_req_addr(a_req_addr),
        .a_req_wdata(a_req_wdata),
        .a_req_be(a_req_be),
        .a_rsp_valid(a_rsp_valid),
        .a_rsp_ready(a_rsp_ready),
        .a_rsp_tag(a_rsp_tag),
        .a_rsp_rdata(a_rsp_rdata),
        .a_rsp_error(a_rsp_error)
    );

    cbus_to_axil_bridge #(
        .TAG_WIDTH(TAG_WIDTH),
        .CBUS_IO_BASE_ADDR(IO_BASE_ADDR),
        .CBUS_IO_ADDR_MASK(IO_ADDR_MASK),
        .CBUS_MBX_ENABLE(CBUS_MBX_ENABLE),
        .CBUS_MBX_IO_BASE(CBUS_MBX_IO_BASE),
        .AXIL_BASE_ADDR(AXIL_BASE_ADDR)
    ) axil_bridge (
        .clk(a_clk),
        .rst_n(a_rst_n),
        .req_valid(a_req_valid),
        .req_ready(a_req_ready),
        .req_tag(a_req_tag),
        .req_write(a_req_write),
        .req_addr(a_req_addr),
        .req_wdata(a_req_wdata),
        .req_be(a_req_be),
        .rsp_valid(a_rsp_valid),
        .rsp_ready(a_rsp_ready),
        .rsp_tag(a_rsp_tag),
        .rsp_rdata(a_rsp_rdata),
        .rsp_error(a_rsp_error),
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
