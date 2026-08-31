`timescale 1ns/1ps
`default_nettype none

module cbus_target_engine #(
    parameter logic [15:0] IO_BASE_ADDR = 16'h00d0,
    parameter logic [15:0] IO_ADDR_MASK = 16'hfff8,
    parameter integer WAIT_ASSERT_CYCLES = 4,
    parameter integer TIMEOUT_CYCLES = 600,
    parameter integer RELEASE_HOLD_CYCLES = 1
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        platform_ready,

    input  logic [15:0] cbus_addr_i,
    input  logic [15:0] cbus_data_i,
    input  logic        cbus_bhe_n_i,
    input  logic        cbus_ior_n_i,
    input  logic        cbus_iow_n_i,

    output logic [15:0] cbus_data_o,
    output logic        cbus_data_oe_req,
    output logic        cbus_iordy_oe_req,

    output logic        req_valid,
    input  logic        req_ready,
    output logic        req_write,
    output logic [15:0] req_addr,
    output logic [15:0] req_wdata,
    output logic [1:0]  req_be,

    input  logic        rsp_valid,
    input  logic [15:0] rsp_rdata,
    input  logic        rsp_error,

    output logic        busy,
    output logic        timeout_sticky,
    output logic        invalid_sticky,
    output logic        backend_error_sticky,
    output logic        abort_sticky
);

    localparam logic [2:0] ST_IDLE     = 3'd0;
    localparam logic [2:0] ST_ISSUE    = 3'd1;
    localparam logic [2:0] ST_WAIT_RSP = 3'd2;
    localparam logic [2:0] ST_COMPLETE = 3'd3;
    localparam logic [2:0] ST_HOLD     = 3'd4;
    localparam logic [2:0] ST_IGNORE   = 3'd5;

    logic [2:0] state;
    logic [1:0] ior_n_sync;
    logic [1:0] iow_n_sync;
    logic       ior_n_prev;
    logic       iow_n_prev;
    logic       bus_armed;
    logic       cycle_write;
    logic       data_oe_internal;
    logic       iordy_oe_internal;
    logic       req_valid_internal;
    integer     elapsed_cycles;
    integer     hold_cycles;

    wire ior_n = ior_n_sync[1];
    wire iow_n = iow_n_sync[1];
    wire ior_fall = ior_n_prev && !ior_n;
    wire iow_fall = iow_n_prev && !iow_n;
    wire selected = (cbus_addr_i & IO_ADDR_MASK) == (IO_BASE_ADDR & IO_ADDR_MASK);
    wire [1:0] current_be = {~cbus_bhe_n_i, ~cbus_addr_i[0]};
    wire active_strobe_n = cycle_write ? iow_n : ior_n;
    wire raw_active_strobe_n = cycle_write ? cbus_iow_n_i : cbus_ior_n_i;

    always_comb begin
        cbus_data_oe_req = rst_n && platform_ready && data_oe_internal && !cycle_write;
        cbus_iordy_oe_req = rst_n && platform_ready && iordy_oe_internal && !raw_active_strobe_n;
        req_valid = rst_n && platform_ready && req_valid_internal;
        busy = state != ST_IDLE;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ior_n_sync <= 2'b11;
            iow_n_sync <= 2'b11;
            ior_n_prev <= 1'b1;
            iow_n_prev <= 1'b1;
            bus_armed <= 1'b0;
        end else if (!platform_ready) begin
            ior_n_sync <= 2'b11;
            iow_n_sync <= 2'b11;
            ior_n_prev <= 1'b1;
            iow_n_prev <= 1'b1;
            bus_armed <= 1'b0;
        end else begin
            ior_n_sync <= {ior_n_sync[0], cbus_ior_n_i};
            iow_n_sync <= {iow_n_sync[0], cbus_iow_n_i};
            ior_n_prev <= ior_n;
            iow_n_prev <= iow_n;
            if (!bus_armed && ior_n && iow_n && cbus_ior_n_i && cbus_iow_n_i)
                bus_armed <= 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            cycle_write <= 1'b0;
            data_oe_internal <= 1'b0;
            iordy_oe_internal <= 1'b0;
            cbus_data_o <= 16'h0000;
            req_valid_internal <= 1'b0;
            req_write <= 1'b0;
            req_addr <= 16'h0000;
            req_wdata <= 16'h0000;
            req_be <= 2'b00;
            elapsed_cycles <= 0;
            hold_cycles <= 0;
            timeout_sticky <= 1'b0;
            invalid_sticky <= 1'b0;
            backend_error_sticky <= 1'b0;
            abort_sticky <= 1'b0;
        end else if (!platform_ready) begin
            state <= ST_IDLE;
            cycle_write <= 1'b0;
            data_oe_internal <= 1'b0;
            iordy_oe_internal <= 1'b0;
            req_valid_internal <= 1'b0;
            elapsed_cycles <= 0;
            hold_cycles <= 0;
            abort_sticky <= abort_sticky | (state != ST_IDLE);
        end else begin
            case (state)
                ST_IDLE: begin
                    data_oe_internal <= 1'b0;
                    iordy_oe_internal <= 1'b0;
                    req_valid_internal <= 1'b0;
                    elapsed_cycles <= 0;
                    hold_cycles <= 0;

                    if (bus_armed && (ior_fall || iow_fall)) begin
                        if (!ior_n && !iow_n) begin
                            invalid_sticky <= 1'b1;
                            state <= ST_IGNORE;
                        end else if (!selected) begin
                            state <= ST_IGNORE;
                        end else if (current_be == 2'b00) begin
                            invalid_sticky <= 1'b1;
                            state <= ST_IGNORE;
                        end else begin
                            cycle_write <= iow_fall;
                            req_write <= iow_fall;
                            req_addr <= cbus_addr_i;
                            req_wdata <= cbus_data_i;
                            req_be <= current_be;
                            req_valid_internal <= 1'b1;
                            state <= ST_ISSUE;
                        end
                    end
                end

                ST_ISSUE: begin
                    elapsed_cycles <= elapsed_cycles + 1;
                    if (active_strobe_n || raw_active_strobe_n) begin
                        req_valid_internal <= 1'b0;
                        iordy_oe_internal <= 1'b0;
                        abort_sticky <= 1'b1;
                        state <= ST_IDLE;
                    end else if (elapsed_cycles >= TIMEOUT_CYCLES - 1) begin
                        req_valid_internal <= 1'b0;
                        iordy_oe_internal <= 1'b0;
                        timeout_sticky <= 1'b1;
                        if (!cycle_write) begin
                            cbus_data_o <= 16'hffff;
                            data_oe_internal <= 1'b1;
                        end
                        state <= ST_COMPLETE;
                    end else begin
                        if (elapsed_cycles >= WAIT_ASSERT_CYCLES - 1)
                            iordy_oe_internal <= 1'b1;
                        if (req_valid_internal && req_ready) begin
                            req_valid_internal <= 1'b0;
                            state <= ST_WAIT_RSP;
                        end
                    end
                end

                ST_WAIT_RSP: begin
                    elapsed_cycles <= elapsed_cycles + 1;
                    if (active_strobe_n || (raw_active_strobe_n && !data_oe_internal)) begin
                        iordy_oe_internal <= 1'b0;
                        abort_sticky <= 1'b1;
                        state <= ST_IDLE;
                    end else if (rsp_valid) begin
                        iordy_oe_internal <= 1'b0;
                        if (rsp_error)
                            backend_error_sticky <= 1'b1;
                        if (!cycle_write) begin
                            cbus_data_o <= rsp_error ? 16'he001 : rsp_rdata;
                            data_oe_internal <= 1'b1;
                        end
                        state <= ST_COMPLETE;
                    end else if (elapsed_cycles >= TIMEOUT_CYCLES - 1) begin
                        iordy_oe_internal <= 1'b0;
                        timeout_sticky <= 1'b1;
                        if (!cycle_write) begin
                            cbus_data_o <= 16'hffff;
                            data_oe_internal <= 1'b1;
                        end
                        state <= ST_COMPLETE;
                    end else if (elapsed_cycles >= WAIT_ASSERT_CYCLES - 1) begin
                        iordy_oe_internal <= 1'b1;
                    end
                end

                ST_COMPLETE: begin
                    iordy_oe_internal <= 1'b0;
                    if (active_strobe_n) begin
                        hold_cycles <= 0;
                        state <= ST_HOLD;
                    end
                end

                ST_HOLD: begin
                    if (hold_cycles >= RELEASE_HOLD_CYCLES - 1) begin
                        data_oe_internal <= 1'b0;
                        state <= ST_IDLE;
                    end else begin
                        hold_cycles <= hold_cycles + 1;
                    end
                end

                ST_IGNORE: begin
                    data_oe_internal <= 1'b0;
                    iordy_oe_internal <= 1'b0;
                    req_valid_internal <= 1'b0;
                    if (ior_n && iow_n)
                        state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                    data_oe_internal <= 1'b0;
                    iordy_oe_internal <= 1'b0;
                    req_valid_internal <= 1'b0;
                    invalid_sticky <= 1'b1;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
