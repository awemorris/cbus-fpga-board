`timescale 1ns/1ps
`default_nettype none

module axil_control_fabric_1x3 (
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
    input  logic        s_axil_rready,

    output logic [31:0] m0_axil_awaddr,
    output logic [2:0]  m0_axil_awprot,
    output logic        m0_axil_awvalid,
    input  logic        m0_axil_awready,
    output logic [31:0] m0_axil_wdata,
    output logic [3:0]  m0_axil_wstrb,
    output logic        m0_axil_wvalid,
    input  logic        m0_axil_wready,
    input  logic [1:0]  m0_axil_bresp,
    input  logic        m0_axil_bvalid,
    output logic        m0_axil_bready,
    output logic [31:0] m0_axil_araddr,
    output logic [2:0]  m0_axil_arprot,
    output logic        m0_axil_arvalid,
    input  logic        m0_axil_arready,
    input  logic [31:0] m0_axil_rdata,
    input  logic [1:0]  m0_axil_rresp,
    input  logic        m0_axil_rvalid,
    output logic        m0_axil_rready,

    output logic [31:0] m1_axil_awaddr,
    output logic [2:0]  m1_axil_awprot,
    output logic        m1_axil_awvalid,
    input  logic        m1_axil_awready,
    output logic [31:0] m1_axil_wdata,
    output logic [3:0]  m1_axil_wstrb,
    output logic        m1_axil_wvalid,
    input  logic        m1_axil_wready,
    input  logic [1:0]  m1_axil_bresp,
    input  logic        m1_axil_bvalid,
    output logic        m1_axil_bready,
    output logic [31:0] m1_axil_araddr,
    output logic [2:0]  m1_axil_arprot,
    output logic        m1_axil_arvalid,
    input  logic        m1_axil_arready,
    input  logic [31:0] m1_axil_rdata,
    input  logic [1:0]  m1_axil_rresp,
    input  logic        m1_axil_rvalid,
    output logic        m1_axil_rready,

    output logic [31:0] m2_axil_awaddr,
    output logic [2:0]  m2_axil_awprot,
    output logic        m2_axil_awvalid,
    input  logic        m2_axil_awready,
    output logic [31:0] m2_axil_wdata,
    output logic [3:0]  m2_axil_wstrb,
    output logic        m2_axil_wvalid,
    input  logic        m2_axil_wready,
    input  logic [1:0]  m2_axil_bresp,
    input  logic        m2_axil_bvalid,
    output logic        m2_axil_bready,
    output logic [31:0] m2_axil_araddr,
    output logic [2:0]  m2_axil_arprot,
    output logic        m2_axil_arvalid,
    input  logic        m2_axil_arready,
    input  logic [31:0] m2_axil_rdata,
    input  logic [1:0]  m2_axil_rresp,
    input  logic        m2_axil_rvalid,
    output logic        m2_axil_rready
);

    localparam logic [1:0] W_COLLECT = 2'd0;
    localparam logic [1:0] W_SEND    = 2'd1;
    localparam logic [1:0] W_RESP    = 2'd2;
    localparam logic [1:0] W_LOCAL   = 2'd3;
    localparam logic [1:0] R_IDLE    = 2'd0;
    localparam logic [1:0] R_SEND    = 2'd1;
    localparam logic [1:0] R_RESP    = 2'd2;
    localparam logic [1:0] R_LOCAL   = 2'd3;
    localparam logic [1:0] TARGET_SYS  = 2'd0;
    localparam logic [1:0] TARGET_INTR = 2'd1;
    localparam logic [1:0] TARGET_MBX  = 2'd2;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    logic [1:0] w_state;
    logic [1:0] r_state;
    logic aw_pending;
    logic w_pending;
    logic [31:0] awaddr_hold;
    logic [2:0] awprot_hold;
    logic [31:0] wdata_hold;
    logic [3:0] wstrb_hold;
    logic write_aw_done;
    logic write_w_done;
    logic [1:0] write_target;
    logic [31:0] araddr_hold;
    logic [2:0] arprot_hold;
    logic [1:0] read_target;

    wire aw_accept = s_axil_awvalid && s_axil_awready;
    wire w_accept = s_axil_wvalid && s_axil_wready;
    wire have_aw = aw_pending || aw_accept;
    wire have_w = w_pending || w_accept;
    wire [31:0] commit_awaddr = aw_pending ? awaddr_hold : s_axil_awaddr;
    wire selected_awready = (write_target == TARGET_SYS) ? m0_axil_awready :
                            (write_target == TARGET_INTR) ? m1_axil_awready :
                            m2_axil_awready;
    wire selected_wready = (write_target == TARGET_SYS) ? m0_axil_wready :
                           (write_target == TARGET_INTR) ? m1_axil_wready :
                           m2_axil_wready;
    wire selected_bvalid = (write_target == TARGET_SYS) ? m0_axil_bvalid :
                           (write_target == TARGET_INTR) ? m1_axil_bvalid :
                           m2_axil_bvalid;
    wire [1:0] selected_bresp = (write_target == TARGET_SYS) ? m0_axil_bresp :
                                (write_target == TARGET_INTR) ? m1_axil_bresp :
                                m2_axil_bresp;
    wire selected_arready = (read_target == TARGET_SYS) ? m0_axil_arready :
                            (read_target == TARGET_INTR) ? m1_axil_arready :
                            m2_axil_arready;
    wire selected_rvalid = (read_target == TARGET_SYS) ? m0_axil_rvalid :
                           (read_target == TARGET_INTR) ? m1_axil_rvalid :
                           m2_axil_rvalid;
    wire [31:0] selected_rdata = (read_target == TARGET_SYS) ? m0_axil_rdata :
                                 (read_target == TARGET_INTR) ? m1_axil_rdata :
                                 m2_axil_rdata;
    wire [1:0] selected_rresp = (read_target == TARGET_SYS) ? m0_axil_rresp :
                                (read_target == TARGET_INTR) ? m1_axil_rresp :
                                m2_axil_rresp;

    function automatic logic address_valid(input logic [31:0] address);
        begin
            address_valid =
                (address[31:12] == 20'h10000) ||
                (address[31:12] == 20'h10002) ||
                (address[31:12] == 20'h10003);
        end
    endfunction

    function automatic logic [1:0] address_target(input logic [31:0] address);
        begin
            if (address[31:12] == 20'h10002)
                address_target = TARGET_INTR;
            else if (address[31:12] == 20'h10003)
                address_target = TARGET_MBX;
            else
                address_target = TARGET_SYS;
        end
    endfunction

    always_comb begin
        s_axil_awready = (w_state == W_COLLECT) && !aw_pending;
        s_axil_wready = (w_state == W_COLLECT) && !w_pending;
        s_axil_bvalid = (w_state == W_LOCAL) ||
                        ((w_state == W_RESP) && selected_bvalid);
        s_axil_bresp = (w_state == W_LOCAL) ? RESP_DECERR : selected_bresp;
        s_axil_arready = r_state == R_IDLE;
        s_axil_rvalid = (r_state == R_LOCAL) ||
                        ((r_state == R_RESP) && selected_rvalid);
        s_axil_rdata = (r_state == R_LOCAL) ? 32'h0000_0000 : selected_rdata;
        s_axil_rresp = (r_state == R_LOCAL) ? RESP_DECERR : selected_rresp;

        m0_axil_awaddr = awaddr_hold;
        m1_axil_awaddr = awaddr_hold;
        m2_axil_awaddr = awaddr_hold;
        m0_axil_awprot = awprot_hold;
        m1_axil_awprot = awprot_hold;
        m2_axil_awprot = awprot_hold;
        m0_axil_wdata = wdata_hold;
        m1_axil_wdata = wdata_hold;
        m2_axil_wdata = wdata_hold;
        m0_axil_wstrb = wstrb_hold;
        m1_axil_wstrb = wstrb_hold;
        m2_axil_wstrb = wstrb_hold;
        m0_axil_awvalid = (w_state == W_SEND) &&
                          (write_target == TARGET_SYS) && !write_aw_done;
        m1_axil_awvalid = (w_state == W_SEND) &&
                          (write_target == TARGET_INTR) && !write_aw_done;
        m2_axil_awvalid = (w_state == W_SEND) &&
                          (write_target == TARGET_MBX) && !write_aw_done;
        m0_axil_wvalid = (w_state == W_SEND) &&
                         (write_target == TARGET_SYS) && !write_w_done;
        m1_axil_wvalid = (w_state == W_SEND) &&
                         (write_target == TARGET_INTR) && !write_w_done;
        m2_axil_wvalid = (w_state == W_SEND) &&
                         (write_target == TARGET_MBX) && !write_w_done;
        m0_axil_bready = (w_state == W_RESP) &&
                         (write_target == TARGET_SYS) && s_axil_bready;
        m1_axil_bready = (w_state == W_RESP) &&
                         (write_target == TARGET_INTR) && s_axil_bready;
        m2_axil_bready = (w_state == W_RESP) &&
                         (write_target == TARGET_MBX) && s_axil_bready;

        m0_axil_araddr = araddr_hold;
        m1_axil_araddr = araddr_hold;
        m2_axil_araddr = araddr_hold;
        m0_axil_arprot = arprot_hold;
        m1_axil_arprot = arprot_hold;
        m2_axil_arprot = arprot_hold;
        m0_axil_arvalid = (r_state == R_SEND) && (read_target == TARGET_SYS);
        m1_axil_arvalid = (r_state == R_SEND) && (read_target == TARGET_INTR);
        m2_axil_arvalid = (r_state == R_SEND) && (read_target == TARGET_MBX);
        m0_axil_rready = (r_state == R_RESP) &&
                         (read_target == TARGET_SYS) && s_axil_rready;
        m1_axil_rready = (r_state == R_RESP) &&
                         (read_target == TARGET_INTR) && s_axil_rready;
        m2_axil_rready = (r_state == R_RESP) &&
                         (read_target == TARGET_MBX) && s_axil_rready;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state <= W_COLLECT;
            aw_pending <= 1'b0;
            w_pending <= 1'b0;
            awaddr_hold <= 32'h0000_0000;
            awprot_hold <= 3'b000;
            wdata_hold <= 32'h0000_0000;
            wstrb_hold <= 4'b0000;
            write_aw_done <= 1'b0;
            write_w_done <= 1'b0;
            write_target <= TARGET_SYS;
        end else begin
            case (w_state)
                W_COLLECT: begin
                    write_aw_done <= 1'b0;
                    write_w_done <= 1'b0;
                    if (aw_accept) begin
                        aw_pending <= 1'b1;
                        awaddr_hold <= s_axil_awaddr;
                        awprot_hold <= s_axil_awprot;
                    end
                    if (w_accept) begin
                        w_pending <= 1'b1;
                        wdata_hold <= s_axil_wdata;
                        wstrb_hold <= s_axil_wstrb;
                    end
                    if (have_aw && have_w) begin
                        aw_pending <= 1'b0;
                        w_pending <= 1'b0;
                        if (address_valid(commit_awaddr)) begin
                            write_target <= address_target(commit_awaddr);
                            w_state <= W_SEND;
                        end else begin
                            w_state <= W_LOCAL;
                        end
                    end
                end
                W_SEND: begin
                    if (!write_aw_done && selected_awready)
                        write_aw_done <= 1'b1;
                    if (!write_w_done && selected_wready)
                        write_w_done <= 1'b1;
                    if ((write_aw_done || selected_awready) &&
                        (write_w_done || selected_wready))
                        w_state <= W_RESP;
                end
                W_RESP: begin
                    if (selected_bvalid && s_axil_bready)
                        w_state <= W_COLLECT;
                end
                W_LOCAL: begin
                    if (s_axil_bready)
                        w_state <= W_COLLECT;
                end
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state <= R_IDLE;
            araddr_hold <= 32'h0000_0000;
            arprot_hold <= 3'b000;
            read_target <= TARGET_SYS;
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (s_axil_arvalid && s_axil_arready) begin
                        araddr_hold <= s_axil_araddr;
                        arprot_hold <= s_axil_arprot;
                        if (address_valid(s_axil_araddr)) begin
                            read_target <= address_target(s_axil_araddr);
                            r_state <= R_SEND;
                        end else begin
                            r_state <= R_LOCAL;
                        end
                    end
                end
                R_SEND: begin
                    if (selected_arready)
                        r_state <= R_RESP;
                end
                R_RESP: begin
                    if (selected_rvalid && s_axil_rready)
                        r_state <= R_IDLE;
                end
                R_LOCAL: begin
                    if (s_axil_rready)
                        r_state <= R_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
