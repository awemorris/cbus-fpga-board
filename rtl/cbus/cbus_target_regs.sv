`timescale 1ns/1ps
`default_nettype none

module cbus_target_regs #(
    parameter logic [15:0] IO_BASE_ADDR = 16'h00d0,
    parameter logic [15:0] ID_VALUE = 16'hcb98,
    parameter logic [15:0] VERSION_VALUE = 16'h0001
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        stall_enable,

    input  logic        req_valid,
    output logic        req_ready,
    input  logic        req_write,
    input  logic [15:0] req_addr,
    input  logic [15:0] req_wdata,
    input  logic [1:0]  req_be,

    output logic        rsp_valid,
    output logic [15:0] rsp_rdata,
    output logic        rsp_error,

    input  logic        timeout_sticky,
    input  logic        invalid_sticky,
    input  logic        backend_error_sticky,
    input  logic        abort_sticky,
    output logic [15:0] scratch_value
);

    wire [15:0] status_value = {
        12'h000,
        abort_sticky,
        backend_error_sticky,
        invalid_sticky,
        timeout_sticky
    };

    assign req_ready = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_valid <= 1'b0;
            rsp_rdata <= 16'h0000;
            rsp_error <= 1'b0;
            scratch_value <= 16'h0000;
        end else begin
            rsp_valid <= 1'b0;
            rsp_error <= 1'b0;

            if (req_valid && req_ready && !stall_enable) begin
                rsp_valid <= 1'b1;
                case ({req_addr[15:1], 1'b0} - IO_BASE_ADDR)
                    16'h0000: begin
                        rsp_rdata <= ID_VALUE;
                        rsp_error <= req_write;
                    end
                    16'h0002: begin
                        rsp_rdata <= VERSION_VALUE;
                        rsp_error <= req_write;
                    end
                    16'h0004: begin
                        rsp_rdata <= scratch_value;
                        if (req_write) begin
                            if (req_be[0])
                                scratch_value[7:0] <= req_wdata[7:0];
                            if (req_be[1])
                                scratch_value[15:8] <= req_wdata[15:8];
                        end
                    end
                    16'h0006: begin
                        rsp_rdata <= status_value;
                        rsp_error <= req_write;
                    end
                    default: begin
                        rsp_rdata <= 16'hffff;
                        rsp_error <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule

`default_nettype wire
