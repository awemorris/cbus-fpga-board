`timescale 1ns/1ps
`default_nettype none

// Board-independent termination for builds that intentionally have no local
// AXI target yet.  Every complete transaction returns DECERR.
module axil_error_target (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] s_axil_awaddr,
    input  logic [2:0]  s_axil_awprot,
    input  logic        s_axil_awvalid,
    output logic        s_axil_awready,
    input  logic [31:0] s_axil_wdata,
    input  logic [3:0]  s_axil_wstrb,
    input  logic        s_axil_wvalid,
    output logic        s_axil_wready,
    output logic [1:0]  s_axil_bresp,
    output logic        s_axil_bvalid,
    input  logic        s_axil_bready,
    input  logic [31:0] s_axil_araddr,
    input  logic [2:0]  s_axil_arprot,
    input  logic        s_axil_arvalid,
    output logic        s_axil_arready,
    output logic [31:0] s_axil_rdata,
    output logic [1:0]  s_axil_rresp,
    output logic        s_axil_rvalid,
    input  logic        s_axil_rready
);

    logic aw_seen;
    logic w_seen;

    always_comb begin
        s_axil_awready = !aw_seen && !s_axil_bvalid;
        s_axil_wready = !w_seen && !s_axil_bvalid;
        s_axil_arready = !s_axil_rvalid;
        s_axil_bresp = 2'b11;
        s_axil_rdata = 32'h0000_0000;
        s_axil_rresp = 2'b11;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_seen <= 1'b0;
            w_seen <= 1'b0;
            s_axil_bvalid <= 1'b0;
            s_axil_rvalid <= 1'b0;
        end else begin
            if (s_axil_awvalid && s_axil_awready)
                aw_seen <= 1'b1;
            if (s_axil_wvalid && s_axil_wready)
                w_seen <= 1'b1;

            if ((aw_seen || (s_axil_awvalid && s_axil_awready)) &&
                (w_seen || (s_axil_wvalid && s_axil_wready)) &&
                !s_axil_bvalid) begin
                s_axil_bvalid <= 1'b1;
                aw_seen <= 1'b0;
                w_seen <= 1'b0;
            end else if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
            end

            if (s_axil_arvalid && s_axil_arready)
                s_axil_rvalid <= 1'b1;
            else if (s_axil_rvalid && s_axil_rready)
                s_axil_rvalid <= 1'b0;
        end
    end

    wire unused_payload = ^{
        s_axil_awaddr, s_axil_awprot, s_axil_wdata, s_axil_wstrb,
        s_axil_araddr, s_axil_arprot
    };

endmodule

`default_nettype wire
