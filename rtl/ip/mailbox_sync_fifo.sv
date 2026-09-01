`timescale 1ns/1ps
`default_nettype none

module mailbox_sync_fifo #(
    parameter integer DEPTH = 8,
    parameter integer PTR_WIDTH = 3,
    parameter integer COUNT_WIDTH = 4
) (
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   push_req,
    input  logic [31:0]            push_data,
    input  logic                   pop_req,
    input  logic                   empty_probe_req,
    input  logic                   overflow_clear,
    input  logic                   underflow_clear,
    output logic [31:0]            peek_data,
    output logic [COUNT_WIDTH-1:0] occupancy,
    output logic                   empty,
    output logic                   full,
    output logic                   overflow_sticky,
    output logic                   underflow_sticky,
    output logic                   overflow_event,
    output logic                   underflow_event
);

    logic [31:0] memory [0:DEPTH-1];
    logic [PTR_WIDTH-1:0] write_ptr;
    logic [PTR_WIDTH-1:0] read_ptr;
    logic push_accept;
    logic pop_accept;

    always_comb begin
        empty = (occupancy == {COUNT_WIDTH{1'b0}});
        full = (occupancy == DEPTH);
        push_accept = push_req && (!full || pop_req);
        pop_accept = pop_req && !empty;
        overflow_event = push_req && full && !pop_req;
        underflow_event = (pop_req && empty) || (empty_probe_req && empty);
        peek_data = empty ? 32'h0000_0000 : memory[read_ptr];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= {PTR_WIDTH{1'b0}};
            read_ptr <= {PTR_WIDTH{1'b0}};
            occupancy <= {COUNT_WIDTH{1'b0}};
            overflow_sticky <= 1'b0;
            underflow_sticky <= 1'b0;
        end else begin
            if (push_accept) begin
                memory[write_ptr] <= push_data;
                write_ptr <= write_ptr + 1'b1;
            end
            if (pop_accept)
                read_ptr <= read_ptr + 1'b1;

            case ({push_accept, pop_accept})
                2'b10: occupancy <= occupancy + 1'b1;
                2'b01: occupancy <= occupancy - 1'b1;
                default: occupancy <= occupancy;
            endcase

            overflow_sticky <= (overflow_sticky && !overflow_clear) || overflow_event;
            underflow_sticky <= (underflow_sticky && !underflow_clear) || underflow_event;
        end
    end

    initial begin
        if (DEPTH != (1 << PTR_WIDTH))
            $error("mailbox_sync_fifo DEPTH must equal 2**PTR_WIDTH");
    end

endmodule

`default_nettype wire
