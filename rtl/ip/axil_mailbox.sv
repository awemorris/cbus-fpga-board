`timescale 1ns/1ps
`default_nettype none

module axil_mailbox #(
    parameter logic [31:0] BASE_ADDR = cbus_mailbox_regs_pkg::MBX_BASE
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] cpu_pending,
    input  logic [31:0] host_pending,
    output logic [31:0] cpu_event_set,
    output logic [31:0] host_event_set,

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
    logic [15:0] h2c_host_lo;
    logic [15:0] h2c_host_hi;

    logic h2c_push_req;
    logic h2c_pop_req;
    logic h2c_read_probe_req;
    logic h2c_overflow_clear;
    logic h2c_underflow_clear;
    logic [31:0] h2c_peek_data;
    logic [3:0] h2c_occupancy;
    logic h2c_empty;
    logic h2c_full;
    logic h2c_overflow_sticky;
    logic h2c_underflow_sticky;
    logic h2c_overflow_event;
    logic h2c_underflow_event;

    logic c2h_push_req;
    logic [31:0] c2h_push_data;
    logic c2h_pop_req;
    logic c2h_read_probe_req;
    logic c2h_overflow_clear;
    logic c2h_underflow_clear;
    logic [31:0] c2h_peek_data;
    logic [3:0] c2h_occupancy;
    logic c2h_empty;
    logic c2h_full;
    logic c2h_overflow_sticky;
    logic c2h_underflow_sticky;
    logic c2h_overflow_event;
    logic c2h_underflow_event;

    logic h2c_doorbell_set;
    logic c2h_doorbell_set;
    logic h2c_coalesced_clear;
    logic c2h_coalesced_clear;
    logic h2c_coalesced_sticky;
    logic c2h_coalesced_sticky;

    wire aw_accept = s_axil_awvalid && s_axil_awready;
    wire w_accept = s_axil_wvalid && s_axil_wready;
    wire have_aw = aw_pending || aw_accept;
    wire have_w = w_pending || w_accept;
    wire [31:0] commit_awaddr = aw_pending ? awaddr_hold : s_axil_awaddr;
    wire [31:0] commit_wdata = w_pending ? wdata_hold : s_axil_wdata;
    wire [3:0] commit_wstrb = w_pending ? wstrb_hold : s_axil_wstrb;
    wire write_commit = !s_axil_bvalid && have_aw && have_w;
    wire write_in_block = (commit_awaddr[31:12] == BASE_ADDR[31:12]);
    wire read_in_block = (s_axil_araddr[31:12] == BASE_ADDR[31:12]);
    wire h2c_pending = cpu_pending[0];
    wire c2h_pending = host_pending[1];

    wire [31:0] h2c_status = {
        14'h0000,
        h2c_underflow_sticky,
        h2c_overflow_sticky,
        6'h00,
        h2c_full,
        h2c_empty,
        4'h0,
        h2c_occupancy
    };
    wire [31:0] c2h_status = {
        14'h0000,
        c2h_underflow_sticky,
        c2h_overflow_sticky,
        6'h00,
        c2h_full,
        c2h_empty,
        4'h0,
        c2h_occupancy
    };
    wire [31:0] doorbell_status = {
        14'h0000,
        c2h_coalesced_sticky,
        h2c_coalesced_sticky,
        14'h0000,
        c2h_pending,
        h2c_pending
    };

    mailbox_sync_fifo h2c_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .push_req(h2c_push_req),
        .push_data({h2c_host_hi, h2c_host_lo}),
        .pop_req(h2c_pop_req),
        .empty_probe_req(h2c_read_probe_req),
        .overflow_clear(h2c_overflow_clear),
        .underflow_clear(h2c_underflow_clear),
        .peek_data(h2c_peek_data),
        .occupancy(h2c_occupancy),
        .empty(h2c_empty),
        .full(h2c_full),
        .overflow_sticky(h2c_overflow_sticky),
        .underflow_sticky(h2c_underflow_sticky),
        .overflow_event(h2c_overflow_event),
        .underflow_event(h2c_underflow_event)
    );

    mailbox_sync_fifo c2h_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .push_req(c2h_push_req),
        .push_data(c2h_push_data),
        .pop_req(c2h_pop_req),
        .empty_probe_req(c2h_read_probe_req),
        .overflow_clear(c2h_overflow_clear),
        .underflow_clear(c2h_underflow_clear),
        .peek_data(c2h_peek_data),
        .occupancy(c2h_occupancy),
        .empty(c2h_empty),
        .full(c2h_full),
        .overflow_sticky(c2h_overflow_sticky),
        .underflow_sticky(c2h_underflow_sticky),
        .overflow_event(c2h_overflow_event),
        .underflow_event(c2h_underflow_event)
    );

    always_comb begin
        s_axil_awready = !aw_pending && !s_axil_bvalid;
        s_axil_wready = !w_pending && !s_axil_bvalid;
        s_axil_arready = !s_axil_rvalid;
        cpu_event_set = 32'h0000_0000;
        host_event_set = 32'h0000_0000;
        if (h2c_doorbell_set)
            cpu_event_set = cpu_event_set | cbus_mailbox_regs_pkg::EVENT_H2C_DOORBELL_MASK;
        if (c2h_doorbell_set)
            host_event_set = host_event_set | cbus_mailbox_regs_pkg::EVENT_C2H_DOORBELL_MASK;
        if (h2c_overflow_event)
            cpu_event_set = cpu_event_set | cbus_mailbox_regs_pkg::EVENT_H2C_OVERFLOW_MASK;
        if (h2c_underflow_event)
            cpu_event_set = cpu_event_set | cbus_mailbox_regs_pkg::EVENT_H2C_UNDERFLOW_MASK;
        if (c2h_overflow_event)
            cpu_event_set = cpu_event_set | cbus_mailbox_regs_pkg::EVENT_C2H_OVERFLOW_MASK;
        if (c2h_underflow_event)
            cpu_event_set = cpu_event_set | cbus_mailbox_regs_pkg::EVENT_C2H_UNDERFLOW_MASK;
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
            h2c_host_lo <= 16'h0000;
            h2c_host_hi <= 16'h0000;
            h2c_push_req <= 1'b0;
            h2c_pop_req <= 1'b0;
            h2c_overflow_clear <= 1'b0;
            h2c_underflow_clear <= 1'b0;
            c2h_push_req <= 1'b0;
            c2h_push_data <= 32'h0000_0000;
            c2h_pop_req <= 1'b0;
            c2h_overflow_clear <= 1'b0;
            c2h_underflow_clear <= 1'b0;
            h2c_doorbell_set <= 1'b0;
            c2h_doorbell_set <= 1'b0;
            h2c_coalesced_clear <= 1'b0;
            c2h_coalesced_clear <= 1'b0;
        end else begin
            h2c_push_req <= 1'b0;
            h2c_pop_req <= 1'b0;
            h2c_overflow_clear <= 1'b0;
            h2c_underflow_clear <= 1'b0;
            c2h_push_req <= 1'b0;
            c2h_pop_req <= 1'b0;
            c2h_overflow_clear <= 1'b0;
            c2h_underflow_clear <= 1'b0;
            h2c_doorbell_set <= 1'b0;
            c2h_doorbell_set <= 1'b0;
            h2c_coalesced_clear <= 1'b0;
            c2h_coalesced_clear <= 1'b0;

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

            if (write_commit) begin
                aw_pending <= 1'b0;
                w_pending <= 1'b0;
                s_axil_bvalid <= 1'b1;
                if ((commit_awaddr[1:0] != 2'b00) || !write_in_block) begin
                    s_axil_bresp <= RESP_DECERR;
                end else begin
                    case (commit_awaddr[11:0])
                        12'h010: begin
                            s_axil_bresp <= RESP_OKAY;
                            for (byte_index = 0; byte_index < 2; byte_index = byte_index + 1)
                                if (commit_wstrb[byte_index])
                                    h2c_host_lo[byte_index*8 +: 8] <= commit_wdata[byte_index*8 +: 8];
                        end
                        12'h014: begin
                            s_axil_bresp <= RESP_OKAY;
                            for (byte_index = 0; byte_index < 2; byte_index = byte_index + 1)
                                if (commit_wstrb[byte_index])
                                    h2c_host_hi[byte_index*8 +: 8] <= commit_wdata[byte_index*8 +: 8];
                        end
                        12'h018: begin
                            if (commit_wstrb[0] && commit_wdata[0]) begin
                                s_axil_bresp <= RESP_OKAY;
                                h2c_push_req <= 1'b1;
                            end else begin
                                s_axil_bresp <= RESP_SLVERR;
                            end
                        end
                        12'h020: begin
                            if (commit_wstrb[0] && commit_wdata[0]) begin
                                s_axil_bresp <= RESP_OKAY;
                                h2c_pop_req <= 1'b1;
                            end else begin
                                s_axil_bresp <= RESP_SLVERR;
                            end
                        end
                        12'h028: begin
                            s_axil_bresp <= RESP_OKAY;
                            h2c_overflow_clear <= commit_wstrb[2] && commit_wdata[16];
                        end
                        12'h02c: begin
                            s_axil_bresp <= RESP_OKAY;
                            h2c_underflow_clear <= commit_wstrb[2] && commit_wdata[17];
                        end
                        12'h030: begin
                            if (commit_wstrb == 4'b1111) begin
                                s_axil_bresp <= RESP_OKAY;
                                c2h_push_req <= 1'b1;
                                c2h_push_data <= commit_wdata;
                            end else begin
                                s_axil_bresp <= RESP_SLVERR;
                            end
                        end
                        12'h03c: begin
                            if (commit_wstrb[0] && commit_wdata[0]) begin
                                s_axil_bresp <= RESP_OKAY;
                                c2h_pop_req <= 1'b1;
                            end else begin
                                s_axil_bresp <= RESP_SLVERR;
                            end
                        end
                        12'h044: begin
                            s_axil_bresp <= RESP_OKAY;
                            c2h_overflow_clear <= commit_wstrb[2] && commit_wdata[16];
                        end
                        12'h048: begin
                            s_axil_bresp <= RESP_OKAY;
                            c2h_underflow_clear <= commit_wstrb[2] && commit_wdata[17];
                        end
                        12'h050: begin
                            if (commit_wstrb[0] && commit_wdata[0]) begin
                                s_axil_bresp <= RESP_OKAY;
                                h2c_doorbell_set <= 1'b1;
                            end else begin
                                s_axil_bresp <= RESP_SLVERR;
                            end
                        end
                        12'h054: begin
                            if (commit_wstrb[0] && commit_wdata[1]) begin
                                s_axil_bresp <= RESP_OKAY;
                                c2h_doorbell_set <= 1'b1;
                            end else begin
                                s_axil_bresp <= RESP_SLVERR;
                            end
                        end
                        12'h05c: begin
                            s_axil_bresp <= RESP_OKAY;
                            h2c_coalesced_clear <= commit_wstrb[2] && commit_wdata[16];
                            c2h_coalesced_clear <= commit_wstrb[2] && commit_wdata[17];
                        end
                        12'h000, 12'h004, 12'h01c, 12'h024, 12'h034, 12'h038,
                        12'h040, 12'h058:
                            s_axil_bresp <= RESP_SLVERR;
                        default:
                            s_axil_bresp <= RESP_DECERR;
                    endcase
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h2c_coalesced_sticky <= 1'b0;
            c2h_coalesced_sticky <= 1'b0;
        end else begin
            h2c_coalesced_sticky <=
                (h2c_coalesced_sticky && !h2c_coalesced_clear) ||
                (h2c_doorbell_set && h2c_pending);
            c2h_coalesced_sticky <=
                (c2h_coalesced_sticky && !c2h_coalesced_clear) ||
                (c2h_doorbell_set && c2h_pending);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axil_rdata <= 32'h0000_0000;
            s_axil_rresp <= RESP_OKAY;
            s_axil_rvalid <= 1'b0;
            h2c_read_probe_req <= 1'b0;
            c2h_read_probe_req <= 1'b0;
        end else begin
            h2c_read_probe_req <= 1'b0;
            c2h_read_probe_req <= 1'b0;
            if (s_axil_rvalid && s_axil_rready)
                s_axil_rvalid <= 1'b0;
            if (s_axil_arvalid && s_axil_arready) begin
                s_axil_rvalid <= 1'b1;
                s_axil_rdata <= 32'h0000_0000;
                if ((s_axil_araddr[1:0] != 2'b00) || !read_in_block) begin
                    s_axil_rresp <= RESP_DECERR;
                end else begin
                    s_axil_rresp <= RESP_OKAY;
                    case (s_axil_araddr[11:0])
                        12'h000: s_axil_rdata <= cbus_mailbox_regs_pkg::MBX_ID_RESET;
                        12'h004: s_axil_rdata <= cbus_mailbox_regs_pkg::MBX_CAP_RESET;
                        12'h010: s_axil_rdata <= {16'h0000, h2c_host_lo};
                        12'h014: s_axil_rdata <= {16'h0000, h2c_host_hi};
                        12'h018: s_axil_rdata <= 32'h0000_0000;
                        12'h01c: begin
                            s_axil_rdata <= h2c_peek_data;
                            h2c_read_probe_req <= 1'b1;
                        end
                        12'h020, 12'h028, 12'h02c: s_axil_rdata <= 32'h0000_0000;
                        12'h024: s_axil_rdata <= h2c_status;
                        12'h030: s_axil_rdata <= 32'h0000_0000;
                        12'h034: begin
                            s_axil_rdata <= {16'h0000, c2h_peek_data[15:0]};
                            c2h_read_probe_req <= 1'b1;
                        end
                        12'h038: begin
                            s_axil_rdata <= {16'h0000, c2h_peek_data[31:16]};
                            c2h_read_probe_req <= 1'b1;
                        end
                        12'h03c, 12'h044, 12'h048, 12'h050, 12'h054, 12'h05c:
                            s_axil_rdata <= 32'h0000_0000;
                        12'h040: s_axil_rdata <= c2h_status;
                        12'h058: s_axil_rdata <= doorbell_status;
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
