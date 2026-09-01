`timescale 1ns/1ps
`default_nettype none

module cbus_to_axil_bridge #(
    parameter integer TAG_WIDTH = 8,
    parameter logic [15:0] CBUS_IO_BASE_ADDR = 16'h00d0,
    parameter logic [31:0] AXIL_BASE_ADDR = 32'h1000_0000
) (
    input  logic                   clk,
    input  logic                   rst_n,

    input  logic                   req_valid,
    output logic                   req_ready,
    input  logic [TAG_WIDTH-1:0]   req_tag,
    input  logic                   req_write,
    input  logic [15:0]            req_addr,
    input  logic [15:0]            req_wdata,
    input  logic [1:0]             req_be,

    output logic                   rsp_valid,
    input  logic                   rsp_ready,
    output logic [TAG_WIDTH-1:0]   rsp_tag,
    output logic [15:0]            rsp_rdata,
    output logic                   rsp_error,

    output logic [31:0]            m_axil_awaddr,
    output logic [2:0]             m_axil_awprot,
    output logic                   m_axil_awvalid,
    input  logic                   m_axil_awready,
    output logic [31:0]            m_axil_wdata,
    output logic [3:0]             m_axil_wstrb,
    output logic                   m_axil_wvalid,
    input  logic                   m_axil_wready,
    input  logic [1:0]             m_axil_bresp,
    input  logic                   m_axil_bvalid,
    output logic                   m_axil_bready,

    output logic [31:0]            m_axil_araddr,
    output logic [2:0]             m_axil_arprot,
    output logic                   m_axil_arvalid,
    input  logic                   m_axil_arready,
    input  logic [31:0]            m_axil_rdata,
    input  logic [1:0]             m_axil_rresp,
    input  logic                   m_axil_rvalid,
    output logic                   m_axil_rready
);

    localparam logic [2:0] ST_IDLE       = 3'd0;
    localparam logic [2:0] ST_WRITE_SEND = 3'd1;
    localparam logic [2:0] ST_WRITE_RESP = 3'd2;
    localparam logic [2:0] ST_READ_ADDR  = 3'd3;
    localparam logic [2:0] ST_READ_RESP  = 3'd4;
    localparam logic [2:0] ST_RESULT     = 3'd5;

    logic [2:0] state;
    logic aw_done;
    logic w_done;

    function automatic [31:0] translate_addr(
        input [15:0] cbus_addr
    );
        logic [31:0] byte_offset;
        begin
            byte_offset =
                {16'h0000, (cbus_addr & 16'hfffe)} -
                {16'h0000, (CBUS_IO_BASE_ADDR & 16'hfffe)};
            translate_addr = AXIL_BASE_ADDR + (byte_offset << 1);
        end
    endfunction

    always_comb begin
        req_ready = state == ST_IDLE;
        rsp_valid = state == ST_RESULT;

        m_axil_awprot = 3'b000;
        m_axil_awvalid = (state == ST_WRITE_SEND) && !aw_done;
        m_axil_wvalid = (state == ST_WRITE_SEND) && !w_done;
        m_axil_bready = state == ST_WRITE_RESP;

        m_axil_arprot = 3'b000;
        m_axil_arvalid = state == ST_READ_ADDR;
        m_axil_rready = state == ST_READ_RESP;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            aw_done <= 1'b0;
            w_done <= 1'b0;
            rsp_tag <= '0;
            rsp_rdata <= 16'h0000;
            rsp_error <= 1'b0;
            m_axil_awaddr <= 32'h0000_0000;
            m_axil_wdata <= 32'h0000_0000;
            m_axil_wstrb <= 4'b0000;
            m_axil_araddr <= 32'h0000_0000;
        end else begin
            case (state)
                ST_IDLE: begin
                    aw_done <= 1'b0;
                    w_done <= 1'b0;
                    if (req_valid && req_ready) begin
                        rsp_tag <= req_tag;
                        rsp_rdata <= 16'h0000;
                        rsp_error <= 1'b0;

                        if (req_be == 2'b00) begin
                            rsp_error <= 1'b1;
                            state <= ST_RESULT;
                        end else if (req_write) begin
                            m_axil_awaddr <= translate_addr(req_addr);
                            m_axil_wdata <= {16'h0000, req_wdata};
                            m_axil_wstrb <= {2'b00, req_be};
                            state <= ST_WRITE_SEND;
                        end else begin
                            m_axil_araddr <= translate_addr(req_addr);
                            state <= ST_READ_ADDR;
                        end
                    end
                end

                ST_WRITE_SEND: begin
                    if (m_axil_awvalid && m_axil_awready)
                        aw_done <= 1'b1;
                    if (m_axil_wvalid && m_axil_wready)
                        w_done <= 1'b1;

                    if ((aw_done || m_axil_awready) &&
                        (w_done || m_axil_wready))
                        state <= ST_WRITE_RESP;
                end

                ST_WRITE_RESP: begin
                    if (m_axil_bvalid && m_axil_bready) begin
                        rsp_error <= m_axil_bresp != 2'b00;
                        state <= ST_RESULT;
                    end
                end

                ST_READ_ADDR: begin
                    if (m_axil_arvalid && m_axil_arready)
                        state <= ST_READ_RESP;
                end

                ST_READ_RESP: begin
                    if (m_axil_rvalid && m_axil_rready) begin
                        rsp_rdata <= m_axil_rdata[15:0];
                        rsp_error <= m_axil_rresp != 2'b00;
                        state <= ST_RESULT;
                    end
                end

                ST_RESULT: begin
                    if (rsp_valid && rsp_ready)
                        state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                    aw_done <= 1'b0;
                    w_done <= 1'b0;
                    rsp_error <= 1'b1;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
