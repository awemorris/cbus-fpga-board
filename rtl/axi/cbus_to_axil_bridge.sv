`timescale 1ns/1ps
`default_nettype none

module cbus_to_axil_bridge #(
    parameter integer TAG_WIDTH = 8,
    parameter logic [15:0] CBUS_IO_BASE_ADDR = 16'h00d0,
    parameter logic [15:0] CBUS_IO_ADDR_MASK = 16'hfff8,
    parameter bit          CBUS_MBX_ENABLE = 1'b0,
    parameter logic [15:0] CBUS_MBX_IO_BASE = 16'h0000,
    parameter bit          CBUS_MEM_ENABLE = 1'b0,
    parameter logic [23:0] CBUS_MEM_BASE = 24'h000000,
    parameter logic [23:0] CBUS_MEM_ADDR_MASK = 24'hffffff,
    parameter logic [31:0] AXIL_MEM_TARGET_BASE = 32'h1000_0800,
    parameter logic [31:0] AXIL_BASE_ADDR = 32'h1000_0000
) (
    input  logic                   clk,
    input  logic                   rst_n,

    input  logic                   req_valid,
    output logic                   req_ready,
    input  logic [TAG_WIDTH-1:0]   req_tag,
    input  logic                   req_space_memory,
    input  logic                   req_write,
    input  logic [23:0]            req_addr,
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

    localparam logic [1:0] OP_SINGLE      = 2'd0;
    localparam logic [1:0] OP_DIAG_STATUS = 2'd1;
    localparam logic [1:0] OP_DIAG_ACK    = 2'd2;

    logic [2:0] state;
    logic [1:0] operation;
    logic aw_done;
    logic w_done;
    logic read_upper_half;
    logic [1:0] diag_step;
    logic [15:0] diag_result;
    logic [2:0] diag_ack_bits;
    logic [1:0] diag_ack_current;

    wire request_is_system =
        !req_space_memory &&
        ((req_addr[15:0] & CBUS_IO_ADDR_MASK) ==
         (CBUS_IO_BASE_ADDR & CBUS_IO_ADDR_MASK));
    wire request_is_mailbox = !req_space_memory && CBUS_MBX_ENABLE &&
        ((req_addr[15:0] & 16'hffe0) == (CBUS_MBX_IO_BASE & 16'hffe0));
    wire request_is_memory = req_space_memory && CBUS_MEM_ENABLE &&
        ((req_addr & CBUS_MEM_ADDR_MASK) ==
         (CBUS_MEM_BASE & CBUS_MEM_ADDR_MASK));
    wire [4:0] alias_offset =
        (req_addr[15:0] - CBUS_MBX_IO_BASE) & 16'h001e;

    function automatic [31:0] translate_system_addr(
        input [15:0] cbus_addr
    );
        logic [31:0] byte_offset;
        begin
            byte_offset =
                {16'h0000, (cbus_addr & 16'hfffe)} -
                {16'h0000, (CBUS_IO_BASE_ADDR & 16'hfffe)};
            translate_system_addr = AXIL_BASE_ADDR + (byte_offset << 1);
        end
    endfunction

    function automatic [31:0] translate_memory_addr(
        input [23:0] cbus_addr
    );
        logic [23:0] byte_offset;
        begin
            byte_offset =
                (cbus_addr & 24'hfffffc) -
                (CBUS_MEM_BASE & 24'hfffffc);
            translate_memory_addr =
                AXIL_MEM_TARGET_BASE + {8'h00, byte_offset};
        end
    endfunction

    function automatic [31:0] alias_axil_addr(input [4:0] offset);
        begin
            case (offset)
                5'h00: alias_axil_addr = cbus_mailbox_regs_pkg::MBX_H2C_HOST_LO_ADDR;
                5'h02: alias_axil_addr = cbus_mailbox_regs_pkg::MBX_H2C_HOST_HI_ADDR;
                5'h04: alias_axil_addr = cbus_mailbox_regs_pkg::MBX_H2C_HOST_PUSH_ADDR;
                5'h06: alias_axil_addr = cbus_mailbox_regs_pkg::MBX_H2C_DOORBELL_SET_ADDR;
                5'h08, 5'h0a: alias_axil_addr = cbus_mailbox_regs_pkg::MBX_H2C_STATUS_ADDR;
                5'h0c: alias_axil_addr = cbus_mailbox_regs_pkg::MBX_C2H_HOST_LO_ADDR;
                5'h0e: alias_axil_addr = cbus_mailbox_regs_pkg::MBX_C2H_HOST_HI_ADDR;
                5'h10: alias_axil_addr = cbus_mailbox_regs_pkg::MBX_C2H_HOST_POP_ADDR;
                5'h12, 5'h14: alias_axil_addr = cbus_mailbox_regs_pkg::MBX_C2H_STATUS_ADDR;
                5'h16: alias_axil_addr = cbus_mailbox_regs_pkg::INTR_HOST_PENDING_ADDR;
                5'h18: alias_axil_addr = cbus_mailbox_regs_pkg::INTR_HOST_MASK_ADDR;
                5'h1a: alias_axil_addr = cbus_mailbox_regs_pkg::INTR_HOST_ACK_ADDR;
                default: alias_axil_addr = 32'h0000_0000;
            endcase
        end
    endfunction

    task automatic prepare_diag_ack(input [1:0] which);
        begin
            diag_ack_current <= which;
            case (which)
                2'd0: begin
                    m_axil_awaddr <= cbus_mailbox_regs_pkg::MBX_H2C_HOST_ERR_ACK_ADDR;
                    m_axil_wdata <= 32'h0001_0000;
                end
                2'd1: begin
                    m_axil_awaddr <= cbus_mailbox_regs_pkg::MBX_C2H_HOST_ERR_ACK_ADDR;
                    m_axil_wdata <= 32'h0002_0000;
                end
                default: begin
                    m_axil_awaddr <= cbus_mailbox_regs_pkg::MBX_DOORBELL_COALESCED_ACK_ADDR;
                    m_axil_wdata <= 32'h0002_0000;
                end
            endcase
            m_axil_wstrb <= 4'b0100;
            aw_done <= 1'b0;
            w_done <= 1'b0;
            state <= ST_WRITE_SEND;
        end
    endtask

    initial begin
        if (CBUS_MBX_ENABLE && (CBUS_MBX_IO_BASE[4:0] != 5'b00000))
            $fatal(1, "CBUS_MBX_IO_BASE must be 32-byte aligned");
        if (CBUS_MEM_BASE[1:0] != 2'b00)
            $fatal(1, "CBUS_MEM_BASE must be 32-bit aligned");
        if ((CBUS_MEM_BASE & ~CBUS_MEM_ADDR_MASK) != 24'h000000)
            $fatal(1, "CBUS_MEM_BASE must be aligned to CBUS_MEM_ADDR_MASK");
        if (AXIL_MEM_TARGET_BASE[1:0] != 2'b00)
            $fatal(1, "AXIL_MEM_TARGET_BASE must be 32-bit aligned");
    end

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
        logic [15:0] completed_diag;
        if (!rst_n) begin
            state <= ST_IDLE;
            operation <= OP_SINGLE;
            aw_done <= 1'b0;
            w_done <= 1'b0;
            read_upper_half <= 1'b0;
            diag_step <= 2'd0;
            diag_result <= 16'h0000;
            diag_ack_bits <= 3'b000;
            diag_ack_current <= 2'd0;
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
                    operation <= OP_SINGLE;
                    if (req_valid && req_ready) begin
                        rsp_tag <= req_tag;
                        rsp_rdata <= 16'h0000;
                        rsp_error <= 1'b0;
                        read_upper_half <= 1'b0;
                        diag_result <= 16'h0000;

                        if (req_be == 2'b00) begin
                            rsp_error <= 1'b1;
                            state <= ST_RESULT;
                        end else if (request_is_memory) begin
                            if (req_write) begin
                                m_axil_awaddr <= translate_memory_addr(req_addr);
                                if (req_addr[1]) begin
                                    m_axil_wdata <= {req_wdata, 16'h0000};
                                    m_axil_wstrb <= {req_be, 2'b00};
                                end else begin
                                    m_axil_wdata <= {16'h0000, req_wdata};
                                    m_axil_wstrb <= {2'b00, req_be};
                                end
                                state <= ST_WRITE_SEND;
                            end else begin
                                m_axil_araddr <= translate_memory_addr(req_addr);
                                read_upper_half <= req_addr[1];
                                state <= ST_READ_ADDR;
                            end
                        end else if (request_is_mailbox) begin
                            if (alias_offset == 5'h1c) begin
                                if (req_write) begin
                                    rsp_error <= 1'b1;
                                    state <= ST_RESULT;
                                end else begin
                                    operation <= OP_DIAG_STATUS;
                                    diag_step <= 2'd0;
                                    m_axil_araddr <= cbus_mailbox_regs_pkg::MBX_H2C_STATUS_ADDR;
                                    state <= ST_READ_ADDR;
                                end
                            end else if (alias_offset == 5'h1e) begin
                                if (!req_write) begin
                                    rsp_rdata <= 16'h0000;
                                    state <= ST_RESULT;
                                end else if (!req_be[0] || (req_wdata[2:0] == 3'b000)) begin
                                    state <= ST_RESULT;
                                end else begin
                                    operation <= OP_DIAG_ACK;
                                    diag_ack_bits <= req_wdata[2:0];
                                    if (req_wdata[0])
                                        prepare_diag_ack(2'd0);
                                    else if (req_wdata[1])
                                        prepare_diag_ack(2'd1);
                                    else
                                        prepare_diag_ack(2'd2);
                                end
                            end else if (alias_offset <= 5'h1a) begin
                                if (req_write &&
                                    ((alias_offset == 5'h04) ||
                                     (alias_offset == 5'h06) ||
                                     (alias_offset == 5'h10)) &&
                                    !req_be[0]) begin
                                    state <= ST_RESULT;
                                end else if (req_write) begin
                                    m_axil_awaddr <= alias_axil_addr(alias_offset);
                                    m_axil_wdata <= {16'h0000, req_wdata};
                                    m_axil_wstrb <= {2'b00, req_be};
                                    state <= ST_WRITE_SEND;
                                end else begin
                                    m_axil_araddr <= alias_axil_addr(alias_offset);
                                    read_upper_half <=
                                        (alias_offset == 5'h0a) ||
                                        (alias_offset == 5'h14);
                                    state <= ST_READ_ADDR;
                                end
                            end else begin
                                rsp_error <= 1'b1;
                                state <= ST_RESULT;
                            end
                        end else if (request_is_system) begin
                            if (req_write) begin
                                m_axil_awaddr <= translate_system_addr(req_addr[15:0]);
                                m_axil_wdata <= {16'h0000, req_wdata};
                                m_axil_wstrb <= {2'b00, req_be};
                                state <= ST_WRITE_SEND;
                            end else begin
                                m_axil_araddr <= translate_system_addr(req_addr[15:0]);
                                state <= ST_READ_ADDR;
                            end
                        end else begin
                            rsp_error <= 1'b1;
                            state <= ST_RESULT;
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
                        if (m_axil_bresp != 2'b00) begin
                            rsp_error <= 1'b1;
                            state <= ST_RESULT;
                        end else if (operation == OP_DIAG_ACK) begin
                            if ((diag_ack_current == 2'd0) && diag_ack_bits[1])
                                prepare_diag_ack(2'd1);
                            else if ((diag_ack_current != 2'd2) && diag_ack_bits[2])
                                prepare_diag_ack(2'd2);
                            else
                                state <= ST_RESULT;
                        end else begin
                            state <= ST_RESULT;
                        end
                    end
                end

                ST_READ_ADDR: begin
                    if (m_axil_arvalid && m_axil_arready)
                        state <= ST_READ_RESP;
                end

                ST_READ_RESP: begin
                    if (m_axil_rvalid && m_axil_rready) begin
                        if (m_axil_rresp != 2'b00) begin
                            rsp_error <= 1'b1;
                            state <= ST_RESULT;
                        end else if (operation == OP_DIAG_STATUS) begin
                            completed_diag = diag_result;
                            case (diag_step)
                                2'd0: completed_diag[0] = m_axil_rdata[16];
                                2'd1: completed_diag[1] = m_axil_rdata[17];
                                default: completed_diag[2] = m_axil_rdata[17];
                            endcase
                            diag_result <= completed_diag;
                            if (diag_step == 2'd0) begin
                                diag_step <= 2'd1;
                                m_axil_araddr <= cbus_mailbox_regs_pkg::MBX_C2H_STATUS_ADDR;
                                state <= ST_READ_ADDR;
                            end else if (diag_step == 2'd1) begin
                                diag_step <= 2'd2;
                                m_axil_araddr <= cbus_mailbox_regs_pkg::MBX_DOORBELL_STATUS_ADDR;
                                state <= ST_READ_ADDR;
                            end else begin
                                rsp_rdata <= completed_diag;
                                state <= ST_RESULT;
                            end
                        end else begin
                            rsp_rdata <= read_upper_half ?
                                m_axil_rdata[31:16] : m_axil_rdata[15:0];
                            state <= ST_RESULT;
                        end
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
