`timescale 1ns/1ps
`default_nettype none

module tb_mailbox_sync_fifo;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n;
    logic push_req;
    logic [31:0] push_data;
    logic pop_req;
    logic empty_probe_req;
    logic overflow_clear;
    logic underflow_clear;
    logic [31:0] peek_data;
    logic [3:0] occupancy;
    logic empty, full;
    logic overflow_sticky, underflow_sticky;
    logic overflow_event, underflow_event;
    integer checks;
    integer i;

    mailbox_sync_fifo dut (.*);

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL check=%0d: %s", checks, message);
                $fatal(1);
            end
        end
    endtask

    task automatic cycle(
        input logic do_push,
        input logic [31:0] data,
        input logic do_pop,
        input logic do_probe,
        input logic clear_overflow,
        input logic clear_underflow
    );
        begin
            @(negedge clk);
            push_req = do_push;
            push_data = data;
            pop_req = do_pop;
            empty_probe_req = do_probe;
            overflow_clear = clear_overflow;
            underflow_clear = clear_underflow;
            @(posedge clk);
            @(negedge clk);
            push_req = 1'b0;
            pop_req = 1'b0;
            empty_probe_req = 1'b0;
            overflow_clear = 1'b0;
            underflow_clear = 1'b0;
        end
    endtask

    initial begin
        checks = 0;
        rst_n = 1'b0;
        push_req = 0; push_data = 0; pop_req = 0; empty_probe_req = 0;
        overflow_clear = 0; underflow_clear = 0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        check(empty && !full && occupancy == 0 && peek_data == 0, "reset empty state");
        check(!overflow_sticky && !underflow_sticky, "reset sticky state");

        cycle(0, 0, 0, 0, 0, 0);
        check(occupancy == 0 && !overflow_sticky && !underflow_sticky, "empty none");
        cycle(0, 0, 1, 0, 0, 0);
        check(occupancy == 0 && underflow_sticky, "empty pop rejected with underflow");
        cycle(0, 0, 0, 0, 0, 1);
        check(!underflow_sticky, "underflow W1C");
        cycle(1, 32'h1111_0001, 1, 0, 0, 0);
        check(occupancy == 1 && peek_data == 32'h1111_0001, "empty push+pop accepts push only");
        check(underflow_sticky, "empty push+pop records underflow");

        cycle(1, 32'h2222_0002, 0, 0, 0, 1);
        cycle(1, 32'h3333_0003, 0, 0, 0, 0);
        cycle(1, 32'h4444_0004, 0, 0, 0, 0);
        check(occupancy == 4 && peek_data == 32'h1111_0001, "middle fill ordering");
        cycle(1, 32'h5555_0005, 1, 0, 0, 0);
        check(occupancy == 4 && peek_data == 32'h2222_0002, "middle push+pop keeps occupancy and advances head");

        cycle(1, 32'h6666_0006, 0, 0, 0, 0);
        cycle(1, 32'h7777_0007, 0, 0, 0, 0);
        cycle(1, 32'h8888_0008, 0, 0, 0, 0);
        cycle(1, 32'h9999_0009, 0, 0, 0, 0);
        check(full && occupancy == 8 && peek_data == 32'h2222_0002, "full state");
        cycle(1, 32'haaaa_000a, 0, 0, 0, 0);
        check(full && occupancy == 8 && overflow_sticky, "full push rejected with overflow");
        cycle(1, 32'hbbbb_000b, 1, 0, 1, 0);
        check(full && occupancy == 8 && peek_data == 32'h3333_0003, "full push+pop accepts both");
        check(!overflow_sticky, "overflow clear without new overflow");

        for (i = 3; i <= 9; i = i + 1) begin
            check(peek_data[15:0] == i, "drain preserves pre-existing ordering");
            cycle(0, 0, 1, 0, 0, 0);
        end
        check(peek_data == 32'hbbbb_000b && occupancy == 1, "full collision appends new tail");
        cycle(0, 0, 1, 0, 0, 0);
        check(empty && occupancy == 0, "drain reaches empty");

        cycle(0, 0, 0, 1, 0, 0);
        check(underflow_sticky, "empty peek probe records underflow");
        cycle(0, 0, 1, 0, 0, 1);
        check(underflow_sticky, "underflow set wins over simultaneous clear");

        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        check(occupancy == 0 && empty && !overflow_sticky && !underflow_sticky,
              "reset wins and clears all state");

        $display("PASS tb_mailbox_sync_fifo checks=%0d", checks);
        $finish;
    end
endmodule

`default_nettype wire
