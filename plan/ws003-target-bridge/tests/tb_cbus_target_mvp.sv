`timescale 1ns/1ps
`default_nettype none

module tb_cbus_target_mvp;

    localparam logic [15:0] BASE = 16'h00d0;
    localparam integer MAX_BFM_CYCLES = 80;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic platform_ready = 1'b0;
    logic [15:0] cbus_addr = 16'h0000;
    logic cbus_bhe_n = 1'b1;
    logic cbus_ior_n = 1'b1;
    logic cbus_iow_n = 1'b1;
    logic [15:0] host_data_o = 16'h0000;
    logic host_data_oe = 1'b0;
    logic stall_enable = 1'b0;

    tri [15:0] cbus_data;
    logic [15:0] target_data_o;
    logic target_data_oe;
    logic target_iordy_oe;

    logic req_valid;
    logic req_ready;
    logic req_write;
    logic [15:0] req_addr;
    logic [15:0] req_wdata;
    logic [1:0] req_be;
    logic rsp_valid;
    logic [15:0] rsp_rdata;
    logic rsp_error;
    logic busy;
    logic timeout_sticky;
    logic invalid_sticky;
    logic backend_error_sticky;
    logic abort_sticky;
    logic [15:0] scratch_value;

    integer failures = 0;
    integer checks = 0;

    assign cbus_data = host_data_oe ? host_data_o : 16'hzzzz;
    assign cbus_data = target_data_oe ? target_data_o : 16'hzzzz;

    always #5 clk = ~clk;

    cbus_target_engine #(
        .IO_BASE_ADDR(BASE),
        .IO_ADDR_MASK(16'hfff8),
        .WAIT_ASSERT_CYCLES(3),
        .TIMEOUT_CYCLES(16),
        .RELEASE_HOLD_CYCLES(1)
    ) dut_engine (
        .clk(clk),
        .rst_n(rst_n),
        .platform_ready(platform_ready),
        .cbus_addr_i(cbus_addr),
        .cbus_data_i(cbus_data),
        .cbus_bhe_n_i(cbus_bhe_n),
        .cbus_ior_n_i(cbus_ior_n),
        .cbus_iow_n_i(cbus_iow_n),
        .cbus_data_o(target_data_o),
        .cbus_data_oe_req(target_data_oe),
        .cbus_iordy_oe_req(target_iordy_oe),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_be(req_be),
        .rsp_valid(rsp_valid),
        .rsp_rdata(rsp_rdata),
        .rsp_error(rsp_error),
        .busy(busy),
        .timeout_sticky(timeout_sticky),
        .invalid_sticky(invalid_sticky),
        .backend_error_sticky(backend_error_sticky),
        .abort_sticky(abort_sticky)
    );

    cbus_target_regs #(
        .IO_BASE_ADDR(BASE),
        .ID_VALUE(16'hcb98),
        .VERSION_VALUE(16'h0001)
    ) dut_regs (
        .clk(clk),
        .rst_n(rst_n),
        .stall_enable(stall_enable),
        .req_valid(req_valid),
        .req_ready(req_ready),
        .req_write(req_write),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_be(req_be),
        .rsp_valid(rsp_valid),
        .rsp_rdata(rsp_rdata),
        .rsp_error(rsp_error),
        .timeout_sticky(timeout_sticky),
        .invalid_sticky(invalid_sticky),
        .backend_error_sticky(backend_error_sticky),
        .abort_sticky(abort_sticky),
        .scratch_value(scratch_value)
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

    task automatic set_lane(input logic [15:0] address, input logic [1:0] be);
        begin
            cbus_addr = {address[15:1], ~be[0]};
            cbus_bhe_n = ~be[1];
        end
    endtask

    task automatic wait_idle;
        integer count;
        begin
            count = 0;
            while (busy && count < MAX_BFM_CYCLES) begin
                @(negedge clk);
                count = count + 1;
            end
            check(!busy, "target engine did not return idle");
            repeat (3) @(negedge clk);
        end
    endtask

    task automatic io_read(
        input logic [15:0] address,
        input logic [1:0] be,
        output logic [15:0] value,
        output logic saw_wait,
        output logic got_data
    );
        integer count;
        time cycle_start;
        time wait_start;
        begin
            wait_idle();
            host_data_oe = 1'b0;
            set_lane(address, be);
            cbus_ior_n = 1'b0;
            saw_wait = 1'b0;
            got_data = 1'b0;
            value = 16'h0000;
            count = 0;
            cycle_start = $time;
            wait_start = 0;
            while (!got_data && count < MAX_BFM_CYCLES) begin
                @(negedge clk);
                if (target_iordy_oe && !saw_wait) begin
                    saw_wait = 1'b1;
                    wait_start = $time;
                    check(($time - cycle_start) <= 80, "IORDY assertion exceeded 80ns profile deadline");
                end
                if (target_data_oe) begin
                    got_data = 1'b1;
                    value = cbus_data;
                    if (!saw_wait)
                        check(($time - cycle_start) <= 239, "no-wait read exceeded 486/Pentium response deadline");
                    if (saw_wait) begin
                        check(!target_iordy_oe, "read data became valid before IORDY release");
                        check(($time - wait_start) >= 40, "IORDY Low width was below 40ns");
                        check(($time - wait_start) <= 7000, "IORDY Low width exceeded 7us");
                    end
                end
                count = count + 1;
            end
            cbus_ior_n = 1'b1;
            if (got_data) begin
                #5;
                check(target_data_oe, "read data hold was below 5ns");
            end
            wait_idle();
        end
    endtask

    task automatic io_write(
        input logic [15:0] address,
        input logic [1:0] be,
        input logic [15:0] value,
        output logic saw_wait
    );
        integer count;
        begin
            wait_idle();
            set_lane(address, be);
            host_data_o = value;
            host_data_oe = 1'b1;
            cbus_iow_n = 1'b0;
            saw_wait = 1'b0;
            count = 0;
            while (!busy && count < MAX_BFM_CYCLES) begin
                @(negedge clk);
                count = count + 1;
            end
            check(busy, "write cycle was not recognized");
            repeat (8) begin
                @(negedge clk);
                if (target_iordy_oe)
                    saw_wait = 1'b1;
            end
            cbus_iow_n = 1'b1;
            repeat (3) @(negedge clk);
            host_data_oe = 1'b0;
            wait_idle();
        end
    endtask

    task automatic ignored_read(input logic [15:0] address, input logic [1:0] be);
        integer count;
        logic saw_output;
        begin
            wait_idle();
            set_lane(address, be);
            cbus_ior_n = 1'b0;
            saw_output = 1'b0;
            for (count = 0; count < 12; count = count + 1) begin
                @(negedge clk);
                if (target_data_oe || target_iordy_oe)
                    saw_output = 1'b1;
            end
            cbus_ior_n = 1'b1;
            wait_idle();
            check(!saw_output, "ignored read drove a C-bus output");
        end
    endtask

    always @(posedge clk) begin
        if (host_data_oe && target_data_oe)
            check(1'b0, "C-bus data contention detected");
        if ((host_data_oe || target_data_oe) && (^cbus_data === 1'bx))
            check(1'b0, "X detected on driven C-bus data");
        if (!rst_n || !platform_ready) begin
            check(!target_data_oe, "data OE active while reset/not-ready");
            check(!target_iordy_oe, "IORDY OE active while reset/not-ready");
        end
        if (!cbus_iow_n)
            check(!target_data_oe, "target drove data during I/O write");
    end

    initial begin : run_tests
        logic [15:0] value;
        logic saw_wait;
        logic got_data;
        integer count;

        $dumpfile("tb_cbus_target_mvp.vcd");
        $dumpvars(0, tb_cbus_target_mvp);
        $display("SEED=1 (deterministic BFM)");

        repeat (4) @(negedge clk);
        check(!target_data_oe && !target_iordy_oe, "power-on outputs are not High-Z requests");

        $display("TEST reset_and_platform_gate");
        rst_n = 1'b1;
        repeat (3) @(negedge clk);
        set_lane(BASE, 2'b11);
        cbus_ior_n = 1'b0;
        platform_ready = 1'b1;
        repeat (10) @(negedge clk);
        check(!busy && !target_data_oe && !target_iordy_oe,
              "platform armed in the middle of an active cycle");
        cbus_ior_n = 1'b1;
        repeat (5) @(negedge clk);

        io_read(BASE + 16'h0000, 2'b11, value, saw_wait, got_data);
        check(got_data && value == 16'hcb98, "16-bit ID read mismatch");
        check(!saw_wait, "immediate ID read unexpectedly waited");

        $display("TEST byte_lanes_and_scratch");
        io_read(BASE + 16'h0000, 2'b01, value, saw_wait, got_data);
        check(got_data && value[7:0] == 8'h98, "low-byte ID read mismatch");
        io_read(BASE + 16'h0000, 2'b10, value, saw_wait, got_data);
        check(got_data && value[15:8] == 8'hcb, "high-byte ID read mismatch");

        io_write(BASE + 16'h0004, 2'b11, 16'h1234, saw_wait);
        check(!saw_wait && scratch_value == 16'h1234, "16-bit scratch write mismatch");
        io_write(BASE + 16'h0004, 2'b01, 16'h00aa, saw_wait);
        check(scratch_value == 16'h12aa, "low-byte scratch merge mismatch");
        io_write(BASE + 16'h0004, 2'b10, 16'hbb00, saw_wait);
        check(scratch_value == 16'hbbaa, "high-byte scratch merge mismatch");
        io_read(BASE + 16'h0004, 2'b11, value, saw_wait, got_data);
        check(got_data && value == 16'hbbaa, "scratch readback mismatch");

        $display("TEST nonselected_and_invalid");
        ignored_read(BASE + 16'h0010, 2'b11);
        check(!invalid_sticky, "nonselected address was marked invalid");
        ignored_read(BASE, 2'b00);
        check(invalid_sticky, "invalid byte-enable was not recorded");

        wait_idle();
        set_lane(BASE, 2'b11);
        cbus_ior_n = 1'b0;
        cbus_iow_n = 1'b0;
        repeat (8) @(negedge clk);
        check(!target_data_oe && !target_iordy_oe, "simultaneous read/write strobes drove output");
        cbus_ior_n = 1'b1;
        cbus_iow_n = 1'b1;
        wait_idle();

        $display("TEST backend_error");
        io_write(BASE, 2'b11, 16'h0000, saw_wait);
        check(backend_error_sticky, "write to read-only ID did not report backend error");

        $display("TEST wait_and_timeout");
        stall_enable = 1'b1;
        io_read(BASE, 2'b11, value, saw_wait, got_data);
        check(saw_wait, "stalled backend did not request IORDY wait");
        check(got_data && value == 16'hffff, "timeout read fallback mismatch");
        check(timeout_sticky, "timeout was not recorded");
        check(!target_iordy_oe, "IORDY remained active after timeout");
        stall_enable = 1'b0;

        $display("TEST platform_abort");
        stall_enable = 1'b1;
        wait_idle();
        set_lane(BASE, 2'b11);
        cbus_ior_n = 1'b0;
        count = 0;
        while (!target_iordy_oe && count < MAX_BFM_CYCLES) begin
            @(negedge clk);
            count = count + 1;
        end
        check(target_iordy_oe, "platform-abort setup never entered wait");
        platform_ready = 1'b0;
        #1;
        check(!target_data_oe && !target_iordy_oe, "platform gate did not immediately disable outputs");
        cbus_ior_n = 1'b1;
        repeat (3) @(negedge clk);
        platform_ready = 1'b1;
        stall_enable = 1'b0;
        repeat (5) @(negedge clk);
        check(abort_sticky, "platform abort was not recorded");
        io_read(BASE + 16'h0006, 2'b11, value, saw_wait, got_data);
        check(got_data && value[3:0] == 4'hf, "status CSR did not expose sticky faults");

        $display("TEST reset_abort");
        stall_enable = 1'b1;
        wait_idle();
        set_lane(BASE, 2'b11);
        cbus_ior_n = 1'b0;
        count = 0;
        while (!target_iordy_oe && count < MAX_BFM_CYCLES) begin
            @(negedge clk);
            count = count + 1;
        end
        check(target_iordy_oe, "reset-abort setup never entered wait");
        rst_n = 1'b0;
        #1;
        check(!target_data_oe && !target_iordy_oe, "reset did not immediately disable outputs");
        cbus_ior_n = 1'b1;
        stall_enable = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (5) @(negedge clk);

        $display("TEST post_reset_recovery");
        io_read(BASE + 16'h0002, 2'b11, value, saw_wait, got_data);
        check(got_data && value == 16'h0001, "version read failed after reset abort");
        check(!timeout_sticky && !invalid_sticky && !backend_error_sticky && !abort_sticky,
              "reset did not clear sticky status");

        if (failures == 0) begin
            $display("PASS: %0d checks", checks);
            $finish;
        end else begin
            $fatal(1, "FAIL: %0d of %0d checks failed", failures, checks);
        end
    end

endmodule

`default_nettype wire
