`timescale 1ns/1ps
`default_nettype none

module tb_async_fifo;

    logic w_clk = 1'b0;
    logic r_clk = 1'b0;
    logic w_rst_n = 1'b0;
    logic r_rst_n = 1'b0;
    logic w_valid = 1'b0;
    logic w_ready;
    logic [15:0] w_data = 16'h0000;
    logic r_valid;
    logic r_ready = 1'b0;
    logic [15:0] r_data;

    integer checks = 0;
    integer failures = 0;
    integer index;

    always #5 w_clk = ~w_clk;
    always #7 r_clk = ~r_clk;

    async_fifo #(
        .DATA_WIDTH(16),
        .ADDR_WIDTH(2)
    ) dut (
        .w_clk(w_clk),
        .w_rst_n(w_rst_n),
        .w_valid(w_valid),
        .w_ready(w_ready),
        .w_data(w_data),
        .r_clk(r_clk),
        .r_rst_n(r_rst_n),
        .r_valid(r_valid),
        .r_ready(r_ready),
        .r_data(r_data)
    );

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (!condition) begin
                failures = failures + 1;
                $display("FAIL @ %0t: %s", $time, message);
            end
        end
    endtask

    task automatic push(input logic [15:0] value);
        begin
            @(negedge w_clk);
            while (!w_ready)
                @(negedge w_clk);
            w_data = value;
            w_valid = 1'b1;
            @(negedge w_clk);
            w_valid = 1'b0;
        end
    endtask

    task automatic pop_check(input logic [15:0] expected);
        begin
            @(negedge r_clk);
            while (!r_valid)
                @(negedge r_clk);
            check(r_data === expected, "FIFO ordering/data mismatch");
            r_ready = 1'b1;
            @(negedge r_clk);
            r_ready = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("tb_async_fifo.vcd");
        $dumpvars(0, tb_async_fifo);

        repeat (3) @(negedge w_clk);
        w_rst_n = 1'b1;
        r_rst_n = 1'b1;
        repeat (4) @(negedge w_clk);

        $display("TEST fifo_fill_and_drain");
        push(16'h0000);
        push(16'h0001);
        push(16'h0002);
        push(16'h0003);
        repeat (4) @(negedge w_clk);
        check(!w_ready, "FIFO did not report full after DEPTH pushes");

        pop_check(16'h0000);
        pop_check(16'h0001);
        pop_check(16'h0002);
        pop_check(16'h0003);
        repeat (4) @(negedge r_clk);
        check(!r_valid, "FIFO did not report empty after drain");

        $display("TEST fifo_wrap_and_clock_ratio");
        fork
            begin
                for (index = 0; index < 48; index = index + 1) begin
                    repeat ((index * 3) % 4) @(negedge w_clk);
                    push(16'h4000 + index);
                end
            end
            begin
                integer read_index;
                for (read_index = 0; read_index < 48;
                     read_index = read_index + 1) begin
                    repeat ((read_index * 5) % 3) @(negedge r_clk);
                    pop_check(16'h4000 + read_index);
                end
            end
        join

        repeat (5) @(negedge r_clk);
        check(!r_valid, "FIFO retained data after stress drain");

        $display("TEST coherent_reset");
        push(16'ha5a5);
        w_rst_n = 1'b0;
        r_rst_n = 1'b0;
        repeat (2) @(negedge w_clk);
        w_rst_n = 1'b1;
        r_rst_n = 1'b1;
        repeat (5) @(negedge r_clk);
        check(!r_valid, "reset did not empty FIFO");
        check(w_ready, "reset did not make FIFO writable");

        if (failures == 0) begin
            $display("PASS: %0d checks", checks);
            $finish;
        end else begin
            $fatal(1, "FAIL: %0d of %0d checks failed", failures, checks);
        end
    end

endmodule

`default_nettype wire
