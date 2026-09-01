`timescale 1ns/1ps
`default_nettype none

module axil_system_csr #(
    parameter logic [31:0] BASE_ADDR = 32'h1000_0000,
    parameter logic [31:0] PRODUCT_ID = 32'h4342_cb98,
    parameter logic [15:0] ABI_VERSION = 16'h0002,
    parameter logic [15:0] CAPABILITIES = 16'h00ff
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        cbus_timeout_sticky_async,
    input  logic        cbus_invalid_sticky_async,
    input  logic        cbus_backend_error_sticky_async,
    input  logic        cbus_abort_sticky_async,
    input  logic        guard_faulted,
    input  logic        guard_reject_sticky,
    input  logic        guard_timeout_sticky,
    input  logic        guard_downstream_error_sticky,
    input  logic        guard_fault_valid,
    input  logic [2:0]  guard_fault_code,
    input  logic        guard_fault_write,
    output logic [31:0] scratch_value,

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

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    logic aw_pending;
    logic [31:0] awaddr_hold;
    logic w_pending;
    logic [31:0] wdata_hold;
    logic [3:0] wstrb_hold;
    logic [3:0] cbus_status_meta;
    logic [3:0] cbus_status_sync;

    wire aw_accept = s_axil_awvalid && s_axil_awready;
    wire w_accept = s_axil_wvalid && s_axil_wready;
    wire have_aw = aw_pending || aw_accept;
    wire have_w = w_pending || w_accept;
    wire [31:0] commit_awaddr = aw_pending ? awaddr_hold : s_axil_awaddr;
    wire [31:0] commit_wdata = w_pending ? wdata_hold : s_axil_wdata;
    wire [3:0] commit_wstrb = w_pending ? wstrb_hold : s_axil_wstrb;

    wire [31:0] status_value = {
        16'h0000,
        3'b000,
        guard_fault_code,
        guard_fault_write,
        guard_fault_valid,
        guard_downstream_error_sticky,
        guard_timeout_sticky,
        guard_reject_sticky,
        guard_faulted,
        cbus_status_sync[3],
        cbus_status_sync[2],
        cbus_status_sync[1],
        cbus_status_sync[0]
    };

    always_comb begin
        s_axil_awready = !aw_pending && !s_axil_bvalid;
        s_axil_wready = !w_pending && !s_axil_bvalid;
        s_axil_arready = !s_axil_rvalid;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cbus_status_meta <= 4'b0000;
            cbus_status_sync <= 4'b0000;
        end else begin
            cbus_status_meta <= {
                cbus_abort_sticky_async,
                cbus_backend_error_sticky_async,
                cbus_invalid_sticky_async,
                cbus_timeout_sticky_async
            };
            cbus_status_sync <= cbus_status_meta;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        integer byte_index;
        if (!rst_n) begin
            aw_pending <= 1'b0;
            awaddr_hold <= 32'h0000_0000;
            w_pending <= 1'b0;
            wdata_hold <= 32'h0000_0000;
            wstrb_hold <= 4'b0000;
            s_axil_bresp <= RESP_OKAY;
            s_axil_bvalid <= 1'b0;
            scratch_value <= 32'h0000_0000;
        end else begin
            if (s_axil_bvalid && s_axil_bready)
                s_axil_bvalid <= 1'b0;

            if (aw_accept) begin
                aw_pending <= 1'b1;
                awaddr_hold <= s_axil_awaddr;
            end
            if (w_accept) begin
                w_pending <= 1'b1;
                wdata_hold <= s_axil_wdata;
                wstrb_hold <= s_axil_wstrb;
            end

            if (!s_axil_bvalid && have_aw && have_w) begin
                aw_pending <= 1'b0;
                w_pending <= 1'b0;
                s_axil_bvalid <= 1'b1;
                if ((commit_awaddr[1:0] != 2'b00) ||
                    (commit_awaddr[31:4] != BASE_ADDR[31:4])) begin
                    s_axil_bresp <= RESP_DECERR;
                end else if (commit_awaddr[3:0] == 4'h8) begin
                    s_axil_bresp <= RESP_OKAY;
                    for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                        if (commit_wstrb[byte_index])
                            scratch_value[byte_index*8 +: 8] <= commit_wdata[byte_index*8 +: 8];
                end else begin
                    s_axil_bresp <= RESP_SLVERR;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axil_rdata <= 32'h0000_0000;
            s_axil_rresp <= RESP_OKAY;
            s_axil_rvalid <= 1'b0;
        end else begin
            if (s_axil_rvalid && s_axil_rready)
                s_axil_rvalid <= 1'b0;

            if (s_axil_arvalid && s_axil_arready) begin
                s_axil_rvalid <= 1'b1;
                s_axil_rresp <= RESP_OKAY;
                if ((s_axil_araddr[1:0] != 2'b00) ||
                    (s_axil_araddr[31:4] != BASE_ADDR[31:4])) begin
                    s_axil_rdata <= 32'h0000_0000;
                    s_axil_rresp <= RESP_DECERR;
                end else begin
                    case (s_axil_araddr[3:0])
                        4'h0: s_axil_rdata <= PRODUCT_ID;
                        4'h4: s_axil_rdata <= {CAPABILITIES, ABI_VERSION};
                        4'h8: s_axil_rdata <= scratch_value;
                        4'hc: s_axil_rdata <= status_value;
                        default: begin
                            s_axil_rdata <= 32'h0000_0000;
                            s_axil_rresp <= RESP_DECERR;
                        end
                    endcase
                end
            end
        end
    end

    wire unused_protection = ^{s_axil_awprot, s_axil_arprot};

endmodule

`default_nettype wire
