`timescale 1ns/1ps
`default_nettype none

module tb_cbus_memory_target;

    localparam logic [23:0] MEM_BASE = 24'ha10000;
    localparam integer MAX_CYCLES = 80;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic platform_ready = 1'b0;
    logic [23:0] cbus_addr = 24'h000000;
    logic [15:0] cbus_data = 16'h0000;
    logic cbus_bhe_n = 1'b1;
    logic cbus_sale = 1'b0;
    logic cbus_mrc_n = 1'b1;
    logic cbus_mwc_n = 1'b1;
    logic cbus_mwe_n = 1'b1;
    logic cbus_io_conflict = 1'b0;
    logic [15:0] target_data;
    logic target_data_oe;
    logic target_iordy_oe;
    logic req_valid;
    logic req_ready = 1'b1;
    logic req_write;
    logic [23:0] req_addr;
    logic [15:0] req_wdata;
    logic [1:0] req_be;
    logic rsp_valid = 1'b0;
    logic [15:0] rsp_rdata = 16'h55aa;
    logic rsp_error = 1'b0;
    logic busy;
    logic timeout_sticky;
    logic invalid_sticky;
    logic backend_error_sticky;
    logic abort_sticky;

    logic disabled_req_valid;
    logic disabled_data_oe;
    logic disabled_iordy_oe;
    logic hold_response = 1'b0;
    logic response_error = 1'b0;
    logic response_pending = 1'b0;
    integer response_countdown = 0;
    integer response_delay = 2;
    integer req_count = 0;
    integer write_req_count = 0;
    logic [23:0] last_req_addr;
    logic [15:0] last_req_wdata;
    logic [1:0] last_req_be;
    integer checks = 0;
    integer failures = 0;

    always #5 clk = ~clk;

    cbus_memory_target_engine #(
        .CBUS_MEM_ENABLE(1'b1),
        .CBUS_MEM_BASE(MEM_BASE),
        .CBUS_MEM_ADDR_MASK(24'hffff00),
        .WAIT_ASSERT_CYCLES(2),
        .TIMEOUT_CYCLES(14),
        .RELEASE_HOLD_CYCLES(1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .platform_ready(platform_ready),
        .cbus_addr_i(cbus_addr), .cbus_data_i(cbus_data),
        .cbus_bhe_n_i(cbus_bhe_n), .cbus_sale_i(cbus_sale),
        .cbus_mrc_n_i(cbus_mrc_n), .cbus_mwc_n_i(cbus_mwc_n),
        .cbus_mwe_n_i(cbus_mwe_n),
        .cbus_io_conflict_i(cbus_io_conflict),
        .cbus_data_o(target_data), .cbus_data_oe_req(target_data_oe),
        .cbus_iordy_oe_req(target_iordy_oe),
        .req_valid(req_valid), .req_ready(req_ready),
        .req_write(req_write), .req_addr(req_addr),
        .req_wdata(req_wdata), .req_be(req_be),
        .rsp_valid(rsp_valid), .rsp_rdata(rsp_rdata),
        .rsp_error(rsp_error), .busy(busy),
        .timeout_sticky(timeout_sticky),
        .invalid_sticky(invalid_sticky),
        .backend_error_sticky(backend_error_sticky),
        .abort_sticky(abort_sticky)
    );

    cbus_memory_target_engine #(
        .CBUS_MEM_ENABLE(1'b0),
        .CBUS_MEM_BASE(24'h000000),
        .CBUS_MEM_ADDR_MASK(24'hffffff),
        .WAIT_ASSERT_CYCLES(1),
        .TIMEOUT_CYCLES(4)
    ) disabled_dut (
        .clk(clk), .rst_n(rst_n), .platform_ready(platform_ready),
        .cbus_addr_i(cbus_addr), .cbus_data_i(cbus_data),
        .cbus_bhe_n_i(cbus_bhe_n), .cbus_sale_i(cbus_sale),
        .cbus_mrc_n_i(cbus_mrc_n), .cbus_mwc_n_i(cbus_mwc_n),
        .cbus_mwe_n_i(cbus_mwe_n),
        .cbus_io_conflict_i(cbus_io_conflict),
        .cbus_data_o(), .cbus_data_oe_req(disabled_data_oe),
        .cbus_iordy_oe_req(disabled_iordy_oe),
        .req_valid(disabled_req_valid), .req_ready(1'b1),
        .req_write(), .req_addr(), .req_wdata(), .req_be(),
        .rsp_valid(1'b0), .rsp_rdata(16'h0000), .rsp_error(1'b0),
        .busy(), .timeout_sticky(), .invalid_sticky(),
        .backend_error_sticky(), .abort_sticky()
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

    task automatic set_lane(input logic [16:0] lower_addr,
                            input logic [1:0] be);
        begin
            cbus_addr[16:0] = {lower_addr[16:1], ~be[0]};
            cbus_bhe_n = ~be[1];
        end
    endtask

    task automatic latch_upper(input logic [6:0] upper);
        begin
            cbus_addr[23:17] = upper;
            cbus_sale = 1'b1;
            repeat (3) @(negedge clk);
            cbus_sale = 1'b0;
            repeat (3) @(negedge clk);
        end
    endtask

    task automatic wait_idle;
        integer count;
        begin
            count = 0;
            while (busy && count < MAX_CYCLES) begin
                @(negedge clk);
                count = count + 1;
            end
            check(!busy, "memory engine did not return idle");
            repeat (3) @(negedge clk);
        end
    endtask

    task automatic memory_read(input logic [16:0] lower_addr,
                               input logic [1:0] be,
                               output logic [15:0] value,
                               output logic got_data,
                               output logic saw_wait);
        integer count;
        begin
            wait_idle();
            set_lane(lower_addr, be);
            cbus_mrc_n = 1'b0;
            value = 16'h0000;
            got_data = 1'b0;
            saw_wait = 1'b0;
            count = 0;
            while (!got_data && count < MAX_CYCLES) begin
                @(negedge clk);
                if (target_iordy_oe)
                    saw_wait = 1'b1;
                if (target_data_oe) begin
                    got_data = 1'b1;
                    value = target_data;
                end
                count = count + 1;
            end
            cbus_mrc_n = 1'b1;
            #2;
            if (got_data)
                check(target_data_oe, "memory read hold was too short");
            wait_idle();
        end
    endtask

    task automatic memory_write(input logic [16:0] lower_addr,
                                input logic [1:0] be,
                                input logic [15:0] value,
                                output logic saw_wait);
        integer count;
        begin
            wait_idle();
            set_lane(lower_addr, be);
            cbus_data = value;
            cbus_mwc_n = 1'b0;
            repeat (3) @(negedge clk);
            cbus_mwe_n = 1'b0;
            saw_wait = 1'b0;
            count = 0;
            while (busy && count < MAX_CYCLES) begin
                @(negedge clk);
                if (target_iordy_oe)
                    saw_wait = 1'b1;
                count = count + 1;
                if (!target_iordy_oe && req_count != 0 && count > 5)
                    count = MAX_CYCLES;
            end
            cbus_mwe_n = 1'b1;
            cbus_mwc_n = 1'b1;
            wait_idle();
        end
    endtask

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_valid <= 1'b0;
            rsp_error <= 1'b0;
            response_pending <= 1'b0;
            response_countdown <= 0;
            req_count <= 0;
            write_req_count <= 0;
            last_req_addr <= 24'h000000;
            last_req_wdata <= 16'h0000;
            last_req_be <= 2'b00;
        end else begin
            rsp_valid <= 1'b0;
            if (req_valid && req_ready) begin
                req_count <= req_count + 1;
                if (req_write)
                    write_req_count <= write_req_count + 1;
                last_req_addr <= req_addr;
                last_req_wdata <= req_wdata;
                last_req_be <= req_be;
                response_pending <= !hold_response;
                response_countdown <= response_delay;
            end else if (response_pending) begin
                if (response_countdown == 0) begin
                    rsp_valid <= 1'b1;
                    rsp_error <= response_error;
                    response_pending <= 1'b0;
                end else begin
                    response_countdown <= response_countdown - 1;
                end
            end
        end
    end

    always @(posedge clk) begin
        check(!disabled_req_valid && !disabled_data_oe &&
              !disabled_iordy_oe,
              "default-disabled engine generated activity");
        if (!rst_n || !platform_ready)
            check(!target_data_oe && !target_iordy_oe && !req_valid,
                  "memory output active while reset/not-ready");
        if (!cbus_mwc_n || !cbus_mwe_n)
            check(!target_data_oe, "memory engine drove DB during write");
        if (cbus_io_conflict)
            check(!target_data_oe && !target_iordy_oe && !req_valid,
                  "I/O-memory conflict was not electrically silent");
    end

    initial begin
        logic [15:0] value;
        logic got_data;
        logic saw_wait;
        integer before_count;

        $dumpfile("tb_cbus_memory_target.vcd");
        $dumpvars(0, tb_cbus_memory_target);

        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (3) @(negedge clk);
        platform_ready = 1'b1;
        repeat (5) @(negedge clk);

        $display("TEST requires_sale_and_aperture_decode");
        before_count = req_count;
        memory_read(17'h10000, 2'b11, value, got_data, saw_wait);
        check(!got_data && req_count == before_count,
              "memory cycle responded without a valid SALE latch");
        latch_upper(7'h50);
        memory_read(17'h10000, 2'b11, value, got_data, saw_wait);
        check(got_data && value == 16'h55aa && saw_wait,
              "selected memory read failed");
        check(last_req_addr == 24'ha10000 && last_req_be == 2'b11,
              "SALE address/lane capture mismatch");
        before_count = req_count;
        memory_read(17'h10100, 2'b11, value, got_data, saw_wait);
        check(!got_data && req_count == before_count,
              "out-of-aperture memory cycle responded");

        $display("TEST address_hold_lanes_and_continuous_cycles");
        set_lane(17'h10024, 2'b01);
        cbus_mrc_n = 1'b0;
        repeat (4) @(negedge clk);
        cbus_addr[16:0] = 17'h100ee;
        while (!target_data_oe) @(negedge clk);
        check(last_req_addr == 24'ha10024 && last_req_be == 2'b01,
              "cycle address changed after MRC start");
        cbus_mrc_n = 1'b1;
        wait_idle();
        memory_read(17'h10025, 2'b10, value, got_data, saw_wait);
        check(got_data && last_req_addr == 24'ha10025 &&
              last_req_be == 2'b10, "upper-byte read lane mismatch");
        memory_read(17'h10026, 2'b11, value, got_data, saw_wait);
        check(got_data && last_req_addr == 24'ha10026,
              "back-to-back memory read failed");

        $display("TEST qualified_writes");
        before_count = write_req_count;
        memory_write(17'h10030, 2'b11, 16'h1234, saw_wait);
        check(write_req_count == before_count + 1 &&
              last_req_addr == 24'ha10030,
              "qualified memory write count/address mismatch");
        check(last_req_wdata == 16'h1234 && last_req_be == 2'b11,
              "qualified memory write payload mismatch");
        before_count = write_req_count;
        set_lane(17'h10032, 2'b11);
        cbus_mwc_n = 1'b0;
        repeat (8) @(negedge clk);
        cbus_mwc_n = 1'b1;
        wait_idle();
        check(write_req_count == before_count,
              "MWC-only cycle committed a write");
        cbus_mwe_n = 1'b0;
        repeat (4) @(negedge clk);
        cbus_mwe_n = 1'b1;
        wait_idle();
        check(write_req_count == before_count && invalid_sticky,
              "MWE-only cycle was not rejected");

        $display("TEST invalid_and_conflicting_cycles");
        before_count = req_count;
        set_lane(17'h10040, 2'b00);
        cbus_mrc_n = 1'b0;
        repeat (5) @(negedge clk);
        cbus_mrc_n = 1'b1;
        wait_idle();
        check(req_count == before_count && invalid_sticky,
              "BE=00 memory cycle was not rejected");
        set_lane(17'h10042, 2'b11);
        cbus_mrc_n = 1'b0;
        cbus_mwc_n = 1'b0;
        cbus_mwe_n = 1'b0;
        repeat (5) @(negedge clk);
        check(!target_data_oe && !target_iordy_oe,
              "simultaneous memory strobes drove the bus");
        cbus_mrc_n = 1'b1;
        cbus_mwc_n = 1'b1;
        cbus_mwe_n = 1'b1;
        wait_idle();
        before_count = req_count;
        set_lane(17'h10044, 2'b11);
        cbus_mrc_n = 1'b0;
        cbus_io_conflict = 1'b1;
        repeat (5) @(negedge clk);
        cbus_mrc_n = 1'b1;
        cbus_io_conflict = 1'b0;
        wait_idle();
        check(req_count == before_count && invalid_sticky,
              "I/O-memory conflict issued a request");

        $display("TEST backend_error_timeout_abort_reset");
        response_error = 1'b1;
        memory_read(17'h10050, 2'b11, value, got_data, saw_wait);
        check(got_data && value == 16'he001 && backend_error_sticky,
              "memory backend error mapping failed");
        response_error = 1'b0;
        hold_response = 1'b1;
        memory_read(17'h10052, 2'b11, value, got_data, saw_wait);
        check(got_data && value == 16'hffff && timeout_sticky,
              "memory timeout fallback failed");
        hold_response = 1'b0;
        set_lane(17'h10054, 2'b11);
        cbus_mrc_n = 1'b0;
        repeat (3) @(negedge clk);
        cbus_mrc_n = 1'b1;
        wait_idle();
        check(abort_sticky, "early MRC release did not record abort");

        platform_ready = 1'b0;
        #1;
        check(!target_data_oe && !target_iordy_oe && !req_valid,
              "platform abort did not gate memory outputs");
        rst_n = 1'b0;
        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        repeat (3) @(negedge clk);
        platform_ready = 1'b1;
        repeat (5) @(negedge clk);
        before_count = req_count;
        memory_read(17'h10000, 2'b11, value, got_data, saw_wait);
        check(!got_data && req_count == before_count,
              "reset did not invalidate SALE latch");
        latch_upper(7'h50);
        memory_read(17'h10000, 2'b11, value, got_data, saw_wait);
        check(got_data && !timeout_sticky && !invalid_sticky &&
              !backend_error_sticky && !abort_sticky,
              "memory engine did not recover cleanly after reset");

        if (failures == 0) begin
            $display("PASS: %0d checks", checks);
            $finish;
        end else begin
            $fatal(1, "FAIL: %0d of %0d checks failed", failures, checks);
        end
    end

endmodule

`default_nettype wire
