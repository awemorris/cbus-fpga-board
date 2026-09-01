`timescale 1ns/1ps
`default_nettype none

module async_fifo #(
    parameter integer DATA_WIDTH = 8,
    parameter integer ADDR_WIDTH = 2
) (
    input  logic                  w_clk,
    input  logic                  w_rst_n,
    input  logic                  w_valid,
    output logic                  w_ready,
    input  logic [DATA_WIDTH-1:0] w_data,

    input  logic                  r_clk,
    input  logic                  r_rst_n,
    output logic                  r_valid,
    input  logic                  r_ready,
    output logic [DATA_WIDTH-1:0] r_data
);

    localparam integer DEPTH = 1 << ADDR_WIDTH;
    localparam integer PTR_WIDTH = ADDR_WIDTH + 1;
    localparam logic [PTR_WIDTH-1:0] FULL_COMPARE_MASK =
        (1 << (PTR_WIDTH - 1)) | (1 << (PTR_WIDTH - 2));

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] w_bin;
    logic [PTR_WIDTH-1:0] w_gray;
    (* async_reg = "true" *) logic [PTR_WIDTH-1:0] w_r_gray_sync1;
    (* async_reg = "true" *) logic [PTR_WIDTH-1:0] w_r_gray_sync2;
    logic                 w_full;

    logic [PTR_WIDTH-1:0] r_bin;
    logic [PTR_WIDTH-1:0] r_gray;
    (* async_reg = "true" *) logic [PTR_WIDTH-1:0] r_w_gray_sync1;
    (* async_reg = "true" *) logic [PTR_WIDTH-1:0] r_w_gray_sync2;
    logic                 r_empty;

    wire w_push = w_valid && w_ready;
    wire r_pop = r_valid && r_ready;
    wire [PTR_WIDTH-1:0] w_bin_next = w_bin + w_push;
    wire [PTR_WIDTH-1:0] r_bin_next = r_bin + r_pop;
    wire [PTR_WIDTH-1:0] w_gray_next = bin_to_gray(w_bin_next);
    wire [PTR_WIDTH-1:0] r_gray_next = bin_to_gray(r_bin_next);

    function automatic [PTR_WIDTH-1:0] bin_to_gray(
        input [PTR_WIDTH-1:0] value
    );
        bin_to_gray = (value >> 1) ^ value;
    endfunction

    assign w_ready = !w_full;
    assign r_valid = !r_empty;
    assign r_data = mem[r_bin[ADDR_WIDTH-1:0]];

    always_ff @(posedge w_clk or negedge w_rst_n) begin
        if (!w_rst_n) begin
            w_bin <= '0;
            w_gray <= '0;
            w_r_gray_sync1 <= '0;
            w_r_gray_sync2 <= '0;
            w_full <= 1'b0;
        end else begin
            w_r_gray_sync1 <= r_gray;
            w_r_gray_sync2 <= w_r_gray_sync1;

            if (w_push)
                mem[w_bin[ADDR_WIDTH-1:0]] <= w_data;

            w_bin <= w_bin_next;
            w_gray <= w_gray_next;
            w_full <=
                w_gray_next == (w_r_gray_sync2 ^ FULL_COMPARE_MASK);
        end
    end

    always_ff @(posedge r_clk or negedge r_rst_n) begin
        if (!r_rst_n) begin
            r_bin <= '0;
            r_gray <= '0;
            r_w_gray_sync1 <= '0;
            r_w_gray_sync2 <= '0;
            r_empty <= 1'b1;
        end else begin
            r_w_gray_sync1 <= w_gray;
            r_w_gray_sync2 <= r_w_gray_sync1;

            r_bin <= r_bin_next;
            r_gray <= r_gray_next;
            r_empty <= (r_gray_next == r_w_gray_sync2);
        end
    end

endmodule

`default_nettype wire
