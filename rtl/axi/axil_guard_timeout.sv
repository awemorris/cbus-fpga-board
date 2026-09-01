`timescale 1ns/1ps
`default_nettype none

module axil_guard_timeout #(
    parameter logic [31:0] ALLOW_BASE_ADDR = 32'h1000_0000,
    parameter logic [31:0] ALLOW_ADDR_MASK = 32'hffff_f000,
    parameter integer TIMEOUT_CYCLES = 256,
    parameter logic [31:0] ERROR_RDATA = 32'hffff_ffff
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        status_clear,
    input  logic        fault_clear,

    output logic        faulted,
    output logic        fault_reset_req,
    output logic        guard_sticky,
    output logic        timeout_sticky,
    output logic        downstream_error_sticky,
    output logic        fault_valid,
    output logic [2:0]  fault_code,
    output logic        fault_write,
    output logic [31:0] fault_addr,

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

    localparam logic [3:0] ST_IDLE        = 4'd0;
    localparam logic [3:0] ST_W_COLLECT   = 4'd1;
    localparam logic [3:0] ST_W_FORWARD   = 4'd2;
    localparam logic [3:0] ST_W_DOWN_RESP = 4'd3;
    localparam logic [3:0] ST_W_UP_RESP   = 4'd4;
    localparam logic [3:0] ST_R_FORWARD   = 4'd5;
    localparam logic [3:0] ST_R_DOWN_RESP = 4'd6;
    localparam logic [3:0] ST_R_UP_RESP   = 4'd7;

    localparam logic [2:0] FAULT_NONE          = 3'd0;
    localparam logic [2:0] FAULT_GUARD         = 3'd1;
    localparam logic [2:0] FAULT_ISSUE_TIMEOUT = 3'd2;
    localparam logic [2:0] FAULT_ACTIVE_TIMEOUT = 3'd3;
    localparam logic [2:0] FAULT_DOWNSTREAM    = 3'd4;

    logic [3:0] state;
    logic aw_buf_valid;
    logic w_buf_valid;
    logic [31:0] awaddr_buf;
    logic [2:0] awprot_buf;
    logic [31:0] wdata_buf;
    logic [3:0] wstrb_buf;
    logic [31:0] araddr_buf;
    logic [2:0] arprot_buf;
    logic m_aw_pending;
    logic m_w_pending;
    logic m_ar_pending;
    logic [1:0] upstream_bresp;
    logic [31:0] upstream_rdata;
    logic [1:0] upstream_rresp;
    integer timeout_count;

    wire collecting_write =
        (state == ST_IDLE) || (state == ST_W_COLLECT);
    wire take_aw = s_axil_awvalid && s_axil_awready;
    wire take_w = s_axil_wvalid && s_axil_wready;
    wire take_ar = s_axil_arvalid && s_axil_arready;
    wire take_m_aw = m_axil_awvalid && m_axil_awready;
    wire take_m_w = m_axil_wvalid && m_axil_wready;
    wire take_m_ar = m_axil_arvalid && m_axil_arready;

    function automatic logic address_allowed(input logic [31:0] addr);
        address_allowed =
            (addr & ALLOW_ADDR_MASK) ==
            (ALLOW_BASE_ADDR & ALLOW_ADDR_MASK);
    endfunction

    task automatic record_first_fault(
        input logic [2:0] code,
        input logic is_write,
        input logic [31:0] addr
    );
        begin
            if (!fault_valid || status_clear) begin
                fault_valid <= 1'b1;
                fault_code <= code;
                fault_write <= is_write;
                fault_addr <= addr;
            end
        end
    endtask

    always_comb begin
        if (faulted && state == ST_IDLE) begin
            s_axil_awready = s_axil_awvalid && s_axil_wvalid;
            s_axil_wready = s_axil_awvalid && s_axil_wvalid;
            s_axil_arready = !s_axil_awvalid && !s_axil_wvalid;
        end else begin
            s_axil_awready =
                collecting_write && !aw_buf_valid;
            s_axil_wready =
                collecting_write && !w_buf_valid;
            s_axil_arready =
                (state == ST_IDLE) && !aw_buf_valid && !w_buf_valid &&
                !s_axil_awvalid && !s_axil_wvalid;
        end

        s_axil_bvalid = state == ST_W_UP_RESP;
        s_axil_bresp = upstream_bresp;
        s_axil_rvalid = state == ST_R_UP_RESP;
        s_axil_rdata = upstream_rdata;
        s_axil_rresp = upstream_rresp;

        m_axil_awaddr = awaddr_buf;
        m_axil_awprot = awprot_buf;
        m_axil_awvalid = m_aw_pending;
        m_axil_wdata = wdata_buf;
        m_axil_wstrb = wstrb_buf;
        m_axil_wvalid = m_w_pending;
        m_axil_bready = (state == ST_W_DOWN_RESP) || faulted;

        m_axil_araddr = araddr_buf;
        m_axil_arprot = arprot_buf;
        m_axil_arvalid = m_ar_pending;
        m_axil_rready = (state == ST_R_DOWN_RESP) || faulted;

        fault_reset_req = faulted;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        logic have_aw;
        logic have_w;
        logic [31:0] selected_awaddr;
        if (!rst_n) begin
            state <= ST_IDLE;
            aw_buf_valid <= 1'b0;
            w_buf_valid <= 1'b0;
            awaddr_buf <= 32'h0000_0000;
            awprot_buf <= 3'b000;
            wdata_buf <= 32'h0000_0000;
            wstrb_buf <= 4'b0000;
            araddr_buf <= 32'h0000_0000;
            arprot_buf <= 3'b000;
            m_aw_pending <= 1'b0;
            m_w_pending <= 1'b0;
            m_ar_pending <= 1'b0;
            upstream_bresp <= 2'b00;
            upstream_rdata <= 32'h0000_0000;
            upstream_rresp <= 2'b00;
            timeout_count <= 0;
            faulted <= 1'b0;
            guard_sticky <= 1'b0;
            timeout_sticky <= 1'b0;
            downstream_error_sticky <= 1'b0;
            fault_valid <= 1'b0;
            fault_code <= FAULT_NONE;
            fault_write <= 1'b0;
            fault_addr <= 32'h0000_0000;
        end else begin
            if (status_clear) begin
                guard_sticky <= 1'b0;
                timeout_sticky <= 1'b0;
                downstream_error_sticky <= 1'b0;
                fault_valid <= 1'b0;
                fault_code <= FAULT_NONE;
                fault_write <= 1'b0;
                fault_addr <= 32'h0000_0000;
            end

            if (take_m_aw)
                m_aw_pending <= 1'b0;
            if (take_m_w)
                m_w_pending <= 1'b0;
            if (take_m_ar)
                m_ar_pending <= 1'b0;

            if (fault_clear && state == ST_IDLE) begin
                faulted <= 1'b0;
                aw_buf_valid <= 1'b0;
                w_buf_valid <= 1'b0;
                m_aw_pending <= 1'b0;
                m_w_pending <= 1'b0;
                m_ar_pending <= 1'b0;
            end

            case (state)
                ST_IDLE, ST_W_COLLECT: begin
                    have_aw = aw_buf_valid || take_aw;
                    have_w = w_buf_valid || take_w;
                    selected_awaddr = take_aw ? s_axil_awaddr : awaddr_buf;

                    if (faulted && take_ar) begin
                        upstream_rdata <= ERROR_RDATA;
                        upstream_rresp <= 2'b11;
                        state <= ST_R_UP_RESP;
                    end else if (faulted && take_aw && take_w) begin
                        upstream_bresp <= 2'b11;
                        state <= ST_W_UP_RESP;
                    end else begin
                        if (take_aw) begin
                            aw_buf_valid <= 1'b1;
                            awaddr_buf <= s_axil_awaddr;
                            awprot_buf <= s_axil_awprot;
                        end
                        if (take_w) begin
                            w_buf_valid <= 1'b1;
                            wdata_buf <= s_axil_wdata;
                            wstrb_buf <= s_axil_wstrb;
                        end
                    end

                    if (!faulted && take_ar) begin
                        araddr_buf <= s_axil_araddr;
                        arprot_buf <= s_axil_arprot;
                        upstream_rdata <= ERROR_RDATA;
                        timeout_count <= 0;
                        if (!address_allowed(s_axil_araddr)) begin
                            upstream_rresp <= 2'b11;
                            guard_sticky <= 1'b1;
                            record_first_fault(
                                FAULT_GUARD, 1'b0, s_axil_araddr);
                            state <= ST_R_UP_RESP;
                        end else begin
                            m_ar_pending <= 1'b1;
                            state <= ST_R_FORWARD;
                        end
                    end else if (!faulted && have_aw && have_w) begin
                        upstream_bresp <= 2'b00;
                        timeout_count <= 0;
                        if (!address_allowed(selected_awaddr)) begin
                            upstream_bresp <= 2'b11;
                            guard_sticky <= 1'b1;
                            record_first_fault(
                                FAULT_GUARD, 1'b1, selected_awaddr);
                            state <= ST_W_UP_RESP;
                        end else begin
                            m_aw_pending <= 1'b1;
                            m_w_pending <= 1'b1;
                            state <= ST_W_FORWARD;
                        end
                    end else if (!faulted && (have_aw || have_w)) begin
                        state <= ST_W_COLLECT;
                    end
                end

                ST_W_FORWARD: begin
                    if ((!m_aw_pending || take_m_aw) &&
                        (!m_w_pending || take_m_w)) begin
                        timeout_count <= 0;
                        state <= ST_W_DOWN_RESP;
                    end else if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                        timeout_sticky <= 1'b1;
                        faulted <= 1'b1;
                        upstream_bresp <= 2'b10;
                        record_first_fault(
                            FAULT_ISSUE_TIMEOUT, 1'b1, awaddr_buf);
                        state <= ST_W_UP_RESP;
                    end else begin
                        timeout_count <= timeout_count + 1;
                    end
                end

                ST_W_DOWN_RESP: begin
                    if (m_axil_bvalid && m_axil_bready) begin
                        upstream_bresp <= m_axil_bresp;
                        if (m_axil_bresp != 2'b00) begin
                            downstream_error_sticky <= 1'b1;
                            record_first_fault(
                                FAULT_DOWNSTREAM, 1'b1, awaddr_buf);
                        end
                        state <= ST_W_UP_RESP;
                    end else if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                        timeout_sticky <= 1'b1;
                        faulted <= 1'b1;
                        upstream_bresp <= 2'b10;
                        record_first_fault(
                            FAULT_ACTIVE_TIMEOUT, 1'b1, awaddr_buf);
                        state <= ST_W_UP_RESP;
                    end else begin
                        timeout_count <= timeout_count + 1;
                    end
                end

                ST_W_UP_RESP: begin
                    if (s_axil_bvalid && s_axil_bready) begin
                        if (!faulted) begin
                            aw_buf_valid <= 1'b0;
                            w_buf_valid <= 1'b0;
                        end
                        timeout_count <= 0;
                        state <= ST_IDLE;
                    end
                end

                ST_R_FORWARD: begin
                    if (take_m_ar) begin
                        timeout_count <= 0;
                        state <= ST_R_DOWN_RESP;
                    end else if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                        timeout_sticky <= 1'b1;
                        faulted <= 1'b1;
                        upstream_rdata <= ERROR_RDATA;
                        upstream_rresp <= 2'b10;
                        record_first_fault(
                            FAULT_ISSUE_TIMEOUT, 1'b0, araddr_buf);
                        state <= ST_R_UP_RESP;
                    end else begin
                        timeout_count <= timeout_count + 1;
                    end
                end

                ST_R_DOWN_RESP: begin
                    if (m_axil_rvalid && m_axil_rready) begin
                        upstream_rdata <= m_axil_rdata;
                        upstream_rresp <= m_axil_rresp;
                        if (m_axil_rresp != 2'b00) begin
                            downstream_error_sticky <= 1'b1;
                            record_first_fault(
                                FAULT_DOWNSTREAM, 1'b0, araddr_buf);
                        end
                        state <= ST_R_UP_RESP;
                    end else if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                        timeout_sticky <= 1'b1;
                        faulted <= 1'b1;
                        upstream_rdata <= ERROR_RDATA;
                        upstream_rresp <= 2'b10;
                        record_first_fault(
                            FAULT_ACTIVE_TIMEOUT, 1'b0, araddr_buf);
                        state <= ST_R_UP_RESP;
                    end else begin
                        timeout_count <= timeout_count + 1;
                    end
                end

                ST_R_UP_RESP: begin
                    if (s_axil_rvalid && s_axil_rready) begin
                        timeout_count <= 0;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                    aw_buf_valid <= 1'b0;
                    w_buf_valid <= 1'b0;
                    m_aw_pending <= 1'b0;
                    m_w_pending <= 1'b0;
                    m_ar_pending <= 1'b0;
                    faulted <= 1'b1;
                    timeout_sticky <= 1'b1;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
