`timescale 1ns/1ps
`default_nettype none

module cbus_req_rsp_cdc #(
    parameter integer TAG_WIDTH = 8,
    parameter integer FIFO_ADDR_WIDTH = 2
) (
    input  logic                   c_clk,
    input  logic                   c_rst_n,

    input  logic                   c_req_valid,
    output logic                   c_req_ready,
    input  logic                   c_req_space_memory,
    input  logic                   c_req_write,
    input  logic [23:0]            c_req_addr,
    input  logic [15:0]            c_req_wdata,
    input  logic [1:0]             c_req_be,

    output logic                   c_rsp_valid,
    output logic [15:0]            c_rsp_rdata,
    output logic                   c_rsp_error,
    output logic                   c_stale_rsp_pulse,

    input  logic                   a_clk,
    input  logic                   a_rst_n,

    output logic                   a_req_valid,
    input  logic                   a_req_ready,
    output logic [TAG_WIDTH-1:0]   a_req_tag,
    output logic                   a_req_space_memory,
    output logic                   a_req_write,
    output logic [23:0]            a_req_addr,
    output logic [15:0]            a_req_wdata,
    output logic [1:0]             a_req_be,

    input  logic                   a_rsp_valid,
    output logic                   a_rsp_ready,
    input  logic [TAG_WIDTH-1:0]   a_rsp_tag,
    input  logic [15:0]            a_rsp_rdata,
    input  logic                   a_rsp_error
);

    localparam integer REQ_WIDTH = TAG_WIDTH + 44;
    localparam integer RSP_WIDTH = TAG_WIDTH + 17;

    logic [TAG_WIDTH-1:0] next_tag;
    logic [TAG_WIDTH-1:0] active_tag;

    logic [REQ_WIDTH-1:0] req_w_data;
    logic [REQ_WIDTH-1:0] req_r_data;
    logic                 req_r_valid;

    logic [RSP_WIDTH-1:0] rsp_w_data;
    logic [RSP_WIDTH-1:0] rsp_r_data;
    logic                 rsp_r_valid;
    logic                 rsp_tag_matches;

    assign req_w_data = {
        next_tag, c_req_space_memory, c_req_write, c_req_addr,
        c_req_wdata, c_req_be
    };

    async_fifo #(
        .DATA_WIDTH(REQ_WIDTH),
        .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) req_fifo (
        .w_clk(c_clk),
        .w_rst_n(c_rst_n),
        .w_valid(c_req_valid),
        .w_ready(c_req_ready),
        .w_data(req_w_data),
        .r_clk(a_clk),
        .r_rst_n(a_rst_n),
        .r_valid(req_r_valid),
        .r_ready(a_req_ready),
        .r_data(req_r_data)
    );

    assign a_req_valid = req_r_valid;
    assign {
        a_req_tag, a_req_space_memory, a_req_write, a_req_addr,
        a_req_wdata, a_req_be
    } = req_r_data;

    assign rsp_w_data = {a_rsp_tag, a_rsp_error, a_rsp_rdata};

    async_fifo #(
        .DATA_WIDTH(RSP_WIDTH),
        .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) rsp_fifo (
        .w_clk(a_clk),
        .w_rst_n(a_rst_n),
        .w_valid(a_rsp_valid),
        .w_ready(a_rsp_ready),
        .w_data(rsp_w_data),
        .r_clk(c_clk),
        .r_rst_n(c_rst_n),
        .r_valid(rsp_r_valid),
        .r_ready(1'b1),
        .r_data(rsp_r_data)
    );

    assign rsp_tag_matches =
        rsp_r_data[RSP_WIDTH-1 -: TAG_WIDTH] == active_tag;
    assign c_rsp_valid = rsp_r_valid && rsp_tag_matches;
    assign c_rsp_error = rsp_r_data[16];
    assign c_rsp_rdata = rsp_r_data[15:0];

    always_ff @(posedge c_clk or negedge c_rst_n) begin
        if (!c_rst_n) begin
            next_tag <= '0;
            active_tag <= '0;
            c_stale_rsp_pulse <= 1'b0;
        end else begin
            c_stale_rsp_pulse <= rsp_r_valid && !rsp_tag_matches;
            if (c_req_valid && c_req_ready) begin
                active_tag <= next_tag;
                next_tag <= next_tag + 1'b1;
            end
        end
    end

endmodule

`default_nettype wire
