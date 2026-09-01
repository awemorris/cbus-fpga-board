`timescale 1ns/1ps
`default_nettype none

module cbus_memory_target_engine #(
    parameter bit          CBUS_MEM_ENABLE = 1'b0,
    parameter logic [23:0] CBUS_MEM_BASE = 24'h000000,
    parameter logic [23:0] CBUS_MEM_ADDR_MASK = 24'hffffff,
    parameter integer WAIT_ASSERT_CYCLES = 4,
    parameter integer TIMEOUT_CYCLES = 600,
    parameter integer RELEASE_HOLD_CYCLES = 1
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        platform_ready,

    input  logic [23:0] cbus_addr_i,
    input  logic [15:0] cbus_data_i,
    input  logic        cbus_bhe_n_i,
    input  logic        cbus_sale_i,
    input  logic        cbus_mrc_n_i,
    input  logic        cbus_mwc_n_i,
    input  logic        cbus_mwe_n_i,
    input  logic        cbus_io_conflict_i,

    output logic [15:0] cbus_data_o,
    output logic        cbus_data_oe_req,
    output logic        cbus_iordy_oe_req,

    output logic        req_valid,
    input  logic        req_ready,
    output logic        req_write,
    output logic [23:0] req_addr,
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

    localparam logic [2:0] ST_IDLE          = 3'd0;
    localparam logic [2:0] ST_WRITE_QUALIFY = 3'd1;
    localparam logic [2:0] ST_ISSUE         = 3'd2;
    localparam logic [2:0] ST_WAIT_RSP      = 3'd3;
    localparam logic [2:0] ST_COMPLETE      = 3'd4;
    localparam logic [2:0] ST_HOLD          = 3'd5;
    localparam logic [2:0] ST_IGNORE        = 3'd6;

    logic [2:0] state;
    logic [1:0] sale_sync;
    logic [1:0] mrc_n_sync;
    logic [1:0] mwc_n_sync;
    logic [1:0] mwe_n_sync;
    logic       sale_prev;
    logic       mrc_n_prev;
    logic       mwc_n_prev;
    logic       mwe_n_prev;
    logic       bus_armed;
    logic       upper_addr_valid;
    logic [6:0] upper_addr_latched;
    logic       cycle_write;
    logic [23:0] cycle_addr;
    logic [1:0] cycle_be;
    logic       data_oe_internal;
    logic       iordy_oe_internal;
    logic       req_valid_internal;
    integer     elapsed_cycles;
    integer     hold_cycles;

    wire sale = sale_sync[1];
    wire mrc_n = mrc_n_sync[1];
    wire mwc_n = mwc_n_sync[1];
    wire mwe_n = mwe_n_sync[1];
    wire sale_rise = !sale_prev && sale;
    wire mrc_fall = mrc_n_prev && !mrc_n;
    wire mwc_fall = mwc_n_prev && !mwc_n;
    wire mwe_fall = mwe_n_prev && !mwe_n;
    wire [23:0] current_addr = {upper_addr_latched, cbus_addr_i[16:0]};
    wire [1:0] current_be = {~cbus_bhe_n_i, ~cbus_addr_i[0]};
    wire selected = CBUS_MEM_ENABLE && upper_addr_valid &&
        ((current_addr & CBUS_MEM_ADDR_MASK) ==
         (CBUS_MEM_BASE & CBUS_MEM_ADDR_MASK));
    wire sync_cycle_active = cycle_write ? (!mwc_n && !mwe_n) : !mrc_n;
    wire raw_cycle_active = cycle_write ?
        (!cbus_mwc_n_i && !cbus_mwe_n_i) : !cbus_mrc_n_i;
    wire any_memory_active = !mrc_n || !mwc_n || !mwe_n;
    wire raw_any_memory_active =
        !cbus_mrc_n_i || !cbus_mwc_n_i || !cbus_mwe_n_i;

    initial begin
        if (CBUS_MEM_BASE[1:0] != 2'b00)
            $fatal(1, "CBUS_MEM_BASE must be 32-bit aligned");
        if ((CBUS_MEM_BASE & ~CBUS_MEM_ADDR_MASK) != 24'h000000)
            $fatal(1, "CBUS_MEM_BASE must be aligned to CBUS_MEM_ADDR_MASK");
    end

    always_comb begin
        cbus_data_oe_req =
            rst_n && platform_ready && CBUS_MEM_ENABLE &&
            data_oe_internal && !cycle_write &&
            !cbus_io_conflict_i;
        cbus_iordy_oe_req =
            rst_n && platform_ready && CBUS_MEM_ENABLE &&
            iordy_oe_internal && raw_any_memory_active &&
            !cbus_io_conflict_i;
        req_valid =
            rst_n && platform_ready && CBUS_MEM_ENABLE &&
            req_valid_internal && raw_cycle_active &&
            !cbus_io_conflict_i;
        busy = state != ST_IDLE;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sale_sync <= 2'b00;
            mrc_n_sync <= 2'b11;
            mwc_n_sync <= 2'b11;
            mwe_n_sync <= 2'b11;
            sale_prev <= 1'b0;
            mrc_n_prev <= 1'b1;
            mwc_n_prev <= 1'b1;
            mwe_n_prev <= 1'b1;
            bus_armed <= 1'b0;
            upper_addr_valid <= 1'b0;
            upper_addr_latched <= 7'h00;
        end else if (!platform_ready) begin
            sale_sync <= 2'b00;
            mrc_n_sync <= 2'b11;
            mwc_n_sync <= 2'b11;
            mwe_n_sync <= 2'b11;
            sale_prev <= 1'b0;
            mrc_n_prev <= 1'b1;
            mwc_n_prev <= 1'b1;
            mwe_n_prev <= 1'b1;
            bus_armed <= 1'b0;
            upper_addr_valid <= 1'b0;
            upper_addr_latched <= 7'h00;
        end else begin
            sale_sync <= {sale_sync[0], cbus_sale_i};
            mrc_n_sync <= {mrc_n_sync[0], cbus_mrc_n_i};
            mwc_n_sync <= {mwc_n_sync[0], cbus_mwc_n_i};
            mwe_n_sync <= {mwe_n_sync[0], cbus_mwe_n_i};
            sale_prev <= sale;
            mrc_n_prev <= mrc_n;
            mwc_n_prev <= mwc_n;
            mwe_n_prev <= mwe_n;
            if (!bus_armed && mrc_n && mwc_n && mwe_n &&
                cbus_mrc_n_i && cbus_mwc_n_i && cbus_mwe_n_i)
                bus_armed <= 1'b1;
            if (CBUS_MEM_ENABLE && sale_rise) begin
                upper_addr_latched <= cbus_addr_i[23:17];
                upper_addr_valid <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            cycle_write <= 1'b0;
            cycle_addr <= 24'h000000;
            cycle_be <= 2'b00;
            data_oe_internal <= 1'b0;
            iordy_oe_internal <= 1'b0;
            cbus_data_o <= 16'h0000;
            req_valid_internal <= 1'b0;
            req_write <= 1'b0;
            req_addr <= 24'h000000;
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
        end else if (!CBUS_MEM_ENABLE) begin
            state <= ST_IDLE;
            cycle_write <= 1'b0;
            data_oe_internal <= 1'b0;
            iordy_oe_internal <= 1'b0;
            req_valid_internal <= 1'b0;
            elapsed_cycles <= 0;
            hold_cycles <= 0;
        end else begin
            case (state)
                ST_IDLE: begin
                    data_oe_internal <= 1'b0;
                    iordy_oe_internal <= 1'b0;
                    req_valid_internal <= 1'b0;
                    elapsed_cycles <= 0;
                    hold_cycles <= 0;

                    if (bus_armed && (mrc_fall || mwc_fall || mwe_fall)) begin
                        if (cbus_io_conflict_i ||
                            (!mrc_n && (!mwc_n || !mwe_n))) begin
                            invalid_sticky <= 1'b1;
                            state <= ST_IGNORE;
                        end else if (mrc_fall) begin
                            cycle_write <= 1'b0;
                            if (!selected) begin
                                state <= ST_IGNORE;
                            end else if (current_be == 2'b00) begin
                                invalid_sticky <= 1'b1;
                                state <= ST_IGNORE;
                            end else begin
                                cycle_addr <= current_addr;
                                cycle_be <= current_be;
                                req_write <= 1'b0;
                                req_addr <= current_addr;
                                req_wdata <= 16'h0000;
                                req_be <= current_be;
                                req_valid_internal <= 1'b1;
                                state <= ST_ISSUE;
                            end
                        end else if (mwc_fall) begin
                            cycle_write <= 1'b1;
                            cycle_addr <= current_addr;
                            cycle_be <= current_be;
                            if (!selected) begin
                                state <= ST_IGNORE;
                            end else if (current_be == 2'b00) begin
                                invalid_sticky <= 1'b1;
                                state <= ST_IGNORE;
                            end else if (!mwe_n) begin
                                req_write <= 1'b1;
                                req_addr <= current_addr;
                                req_wdata <= cbus_data_i;
                                req_be <= current_be;
                                req_valid_internal <= 1'b1;
                                state <= ST_ISSUE;
                            end else begin
                                state <= ST_WRITE_QUALIFY;
                            end
                        end else begin
                            invalid_sticky <= 1'b1;
                            state <= ST_IGNORE;
                        end
                    end
                end

                ST_WRITE_QUALIFY: begin
                    elapsed_cycles <= elapsed_cycles + 1;
                    if (cbus_io_conflict_i || !mrc_n) begin
                        iordy_oe_internal <= 1'b0;
                        invalid_sticky <= 1'b1;
                        state <= ST_IGNORE;
                    end else if (mwc_n || cbus_mwc_n_i) begin
                        iordy_oe_internal <= 1'b0;
                        state <= ST_IDLE;
                    end else if (!mwe_n && !cbus_mwe_n_i) begin
                        req_write <= 1'b1;
                        req_addr <= cycle_addr;
                        req_wdata <= cbus_data_i;
                        req_be <= cycle_be;
                        req_valid_internal <= 1'b1;
                        state <= ST_ISSUE;
                    end else if (elapsed_cycles >= TIMEOUT_CYCLES - 1) begin
                        iordy_oe_internal <= 1'b0;
                        timeout_sticky <= 1'b1;
                        state <= ST_COMPLETE;
                    end else if (elapsed_cycles >= WAIT_ASSERT_CYCLES - 1) begin
                        iordy_oe_internal <= 1'b1;
                    end
                end

                ST_ISSUE: begin
                    elapsed_cycles <= elapsed_cycles + 1;
                    if (cbus_io_conflict_i) begin
                        req_valid_internal <= 1'b0;
                        iordy_oe_internal <= 1'b0;
                        invalid_sticky <= 1'b1;
                        abort_sticky <= 1'b1;
                        state <= ST_IGNORE;
                    end else if (!sync_cycle_active || !raw_cycle_active) begin
                        req_valid_internal <= 1'b0;
                        iordy_oe_internal <= 1'b0;
                        abort_sticky <= 1'b1;
                        state <= ST_IDLE;
                    end else if (req_valid_internal && req_ready) begin
                        req_valid_internal <= 1'b0;
                        state <= ST_WAIT_RSP;
                    end else if (elapsed_cycles >= TIMEOUT_CYCLES - 1) begin
                        req_valid_internal <= 1'b0;
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

                ST_WAIT_RSP: begin
                    elapsed_cycles <= elapsed_cycles + 1;
                    if (cbus_io_conflict_i) begin
                        iordy_oe_internal <= 1'b0;
                        data_oe_internal <= 1'b0;
                        invalid_sticky <= 1'b1;
                        abort_sticky <= 1'b1;
                        state <= ST_IGNORE;
                    end else if (!sync_cycle_active ||
                                 (!raw_cycle_active && !data_oe_internal)) begin
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
                    if (!sync_cycle_active) begin
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
                    if (!any_memory_active && !raw_any_memory_active &&
                        !cbus_io_conflict_i)
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
