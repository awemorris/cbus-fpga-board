`timescale 1ns/1ps
`default_nettype none

module axil_interrupt_router #(
    parameter logic [31:0] BASE_ADDR = cbus_mailbox_regs_pkg::INTR_BASE,
    parameter logic [31:0] CPU_VALID_MASK =
        cbus_mailbox_regs_pkg::INTR_CPU_PENDING_VALID_SOURCES_MASK,
    parameter logic [31:0] HOST_VALID_MASK =
        cbus_mailbox_regs_pkg::INTR_HOST_PENDING_VALID_SOURCES_MASK
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] cpu_event_set,
    input  logic [31:0] host_event_set,
    output logic [31:0] cpu_pending,
    output logic [31:0] cpu_mask,
    output logic [31:0] cpu_active,
    output logic        cpu_irq_active,
    output logic [31:0] host_pending,
    output logic [31:0] host_mask,
    output logic [31:0] host_active,
    output logic        host_irq_active,

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
    wire write_aligned_in_block = (commit_awaddr[1:0] == 2'b00) && write_in_block;
    wire cpu_ack_write = write_commit && write_aligned_in_block &&
                         (commit_awaddr[11:0] == 12'h018);
    wire host_ack_write = write_commit && write_aligned_in_block &&
                          (commit_awaddr[11:0] == 12'h028);
    wire [31:0] cpu_ack_bits = cpu_ack_write ?
        (commit_wdata & strobe_mask(commit_wstrb) & CPU_VALID_MASK) : 32'h0000_0000;
    wire [31:0] host_ack_bits = host_ack_write ?
        (commit_wdata & strobe_mask(commit_wstrb) & HOST_VALID_MASK) : 32'h0000_0000;

    function automatic logic [31:0] strobe_mask(input logic [3:0] strobe);
        begin
            strobe_mask = {
                {8{strobe[3]}}, {8{strobe[2]}},
                {8{strobe[1]}}, {8{strobe[0]}}
            };
        end
    endfunction

    always_comb begin
        s_axil_awready = !aw_pending && !s_axil_bvalid;
        s_axil_wready = !w_pending && !s_axil_bvalid;
        s_axil_arready = !s_axil_rvalid;
        cpu_active = cpu_pending & cpu_mask;
        host_active = host_pending & host_mask;
        cpu_irq_active = |cpu_active;
        host_irq_active = |host_active;
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
            cpu_mask <= 32'h0000_0000;
            host_mask <= 32'h0000_0000;
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

            if (write_commit) begin
                aw_pending <= 1'b0;
                w_pending <= 1'b0;
                s_axil_bvalid <= 1'b1;
                if ((commit_awaddr[1:0] != 2'b00) || !write_in_block) begin
                    s_axil_bresp <= RESP_DECERR;
                end else begin
                    case (commit_awaddr[11:0])
                        12'h014: begin
                            s_axil_bresp <= RESP_OKAY;
                            for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                                if (commit_wstrb[byte_index])
                                    cpu_mask[byte_index*8 +: 8] <=
                                        commit_wdata[byte_index*8 +: 8] &
                                        CPU_VALID_MASK[byte_index*8 +: 8];
                        end
                        12'h018: begin
                            s_axil_bresp <= RESP_OKAY;
                        end
                        12'h024: begin
                            s_axil_bresp <= RESP_OKAY;
                            for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                                if (commit_wstrb[byte_index])
                                    host_mask[byte_index*8 +: 8] <=
                                        commit_wdata[byte_index*8 +: 8] &
                                        HOST_VALID_MASK[byte_index*8 +: 8];
                        end
                        12'h028: begin
                            s_axil_bresp <= RESP_OKAY;
                        end
                        12'h000, 12'h004, 12'h010, 12'h01c, 12'h020, 12'h02c:
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
            cpu_pending <= 32'h0000_0000;
            host_pending <= 32'h0000_0000;
        end else begin
            cpu_pending <= ((cpu_pending & ~cpu_ack_bits) | cpu_event_set) & CPU_VALID_MASK;
            host_pending <= ((host_pending & ~host_ack_bits) | host_event_set) & HOST_VALID_MASK;
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
                s_axil_rdata <= 32'h0000_0000;
                if ((s_axil_araddr[1:0] != 2'b00) || !read_in_block) begin
                    s_axil_rresp <= RESP_DECERR;
                end else begin
                    s_axil_rresp <= RESP_OKAY;
                    case (s_axil_araddr[11:0])
                        12'h000: s_axil_rdata <= cbus_mailbox_regs_pkg::INTR_ID_RESET;
                        12'h004: s_axil_rdata <= cbus_mailbox_regs_pkg::INTR_CAP_RESET;
                        12'h010: s_axil_rdata <= cpu_pending;
                        12'h014: s_axil_rdata <= cpu_mask;
                        12'h018: s_axil_rdata <= 32'h0000_0000;
                        12'h01c: s_axil_rdata <= cpu_active;
                        12'h020: s_axil_rdata <= host_pending;
                        12'h024: s_axil_rdata <= host_mask;
                        12'h028: s_axil_rdata <= 32'h0000_0000;
                        12'h02c: s_axil_rdata <= host_active;
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
