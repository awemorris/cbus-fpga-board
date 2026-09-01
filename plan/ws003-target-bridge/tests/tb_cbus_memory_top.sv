`timescale 1ns/1ps
`default_nettype none

module tb_cbus_memory_top;

    localparam logic [23:0] MEM_BASE = 24'ha10000;
    logic c_clk = 1'b0;
    logic a_clk = 1'b0;
    logic rst_n = 1'b0;
    logic [23:0] cbus_ab_i = 24'h000000;
    logic [15:0] cbus_db_i = 16'h0000;
    logic cbus_ior_n_i = 1'b1;
    logic cbus_iow_n_i = 1'b1;
    logic cbus_mrc_n_i = 1'b1;
    logic cbus_mwc_n_i = 1'b1;
    logic cbus_mwe_n_i = 1'b1;
    logic cbus_bhe_n_i = 1'b0;
    logic cbus_sale_i = 1'b0;
    logic [23:0] cbus_ab_o;
    logic cbus_ab_oe_req;
    logic [15:0] cbus_db_o;
    logic cbus_db_oe_req;
    logic cbus_iordy_oe_req;
    logic cbus_mrc_n_oe_req;
    logic cbus_mwc_n_oe_req;
    logic cbus_mwe_n_oe_req;
    logic lvc_cmd_oe_req;
    logic busy;
    logic timeout_sticky;
    logic invalid_sticky;
    logic backend_error_sticky;
    logic abort_sticky;
    integer checks = 0;
    integer failures = 0;

    always #5 c_clk = ~c_clk;
    always #7 a_clk = ~a_clk;

    cbus_ip_top #(
        .CBUS_MEM_ENABLE(1'b1),
        .CBUS_MEM_BASE(MEM_BASE),
        .CBUS_MEM_ADDR_MASK(24'hfffff0),
        .AXIL_MEM_TARGET_BASE(32'h1000_0000),
        .WAIT_ASSERT_CYCLES(2),
        .CBUS_TIMEOUT_CYCLES(160),
        .AXIL_TIMEOUT_CYCLES(64)
    ) dut (
        .cbus_logic_clk(c_clk), .axi_clk(a_clk), .rst_n(rst_n),
        .platform_ready(1'b1), .guard_status_clear(1'b0),
        .guard_fault_clear(1'b0),
        .cbus_ab_i(cbus_ab_i), .cbus_ab_o(cbus_ab_o),
        .cbus_ab_oe_req(cbus_ab_oe_req), .cbus_db_i(cbus_db_i),
        .cbus_db_o(cbus_db_o), .cbus_db_oe_req(cbus_db_oe_req),
        .cbus_ior_n_i(cbus_ior_n_i), .cbus_ior_n_o(),
        .cbus_ior_n_oe_req(), .cbus_iow_n_i(cbus_iow_n_i),
        .cbus_iow_n_o(), .cbus_iow_n_oe_req(),
        .cbus_mrc_n_i(cbus_mrc_n_i), .cbus_mrc_n_o(),
        .cbus_mrc_n_oe_req(cbus_mrc_n_oe_req),
        .cbus_mwc_n_i(cbus_mwc_n_i), .cbus_mwc_n_o(),
        .cbus_mwc_n_oe_req(cbus_mwc_n_oe_req),
        .cbus_mwe_n_i(cbus_mwe_n_i), .cbus_mwe_n_o(),
        .cbus_mwe_n_oe_req(cbus_mwe_n_oe_req),
        .cbus_bhe_n_i(cbus_bhe_n_i), .cbus_bhe_n_o(),
        .cbus_bhe_n_oe_req(), .cbus_reset_n_i(1'b1),
        .cbus_power_n_i(1'b1), .cbus_sclk_i(1'b0),
        .cbus_sale_i(cbus_sale_i), .cbus_iordy_o(),
        .cbus_iordy_oe_req(cbus_iordy_oe_req), .cbus_irq_assert(),
        .cbus_dack_n_i(1'b1), .cbus_drq_n_assert(),
        .cbus_word_n_o(), .cbus_word_oe_req(),
        .cbus_dmatc_n_i(1'b1), .cbus_exhrq1_n_assert(),
        .cbus_exhrq2_n_assert(), .cbus_exhla1_n_i(1'b1),
        .cbus_exhla2_n_i(1'b1), .cbus_sbusrq_i(1'b0),
        .lvc_data_dir_req(), .lvc_data_oe_req(),
        .lvc_iordy_oe_req(), .lvc_irq_oe_req(),
        .lvc_word_oe_req(), .lvc_addr_dir_req(),
        .lvc_addr_oe_req(), .lvc_cmd_dir_req(),
        .lvc_cmd_oe_req(lvc_cmd_oe_req), .busy(busy),
        .timeout_sticky(timeout_sticky),
        .invalid_sticky(invalid_sticky),
        .backend_error_sticky(backend_error_sticky),
        .abort_sticky(abort_sticky), .stale_rsp_pulse(),
        .guard_faulted(), .guard_fault_reset_req(),
        .guard_reject_sticky(), .guard_timeout_sticky(),
        .guard_downstream_error_sticky(), .guard_fault_valid(),
        .guard_fault_code(), .guard_fault_write(), .guard_fault_addr(),
        .mailbox_cpu_irq_active(), .mailbox_host_irq_active()
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

    task automatic idle(input integer count);
        integer i;
        begin
            for (i = 0; i < count; i = i + 1)
                @(negedge c_clk);
        end
    endtask

    task automatic latch_upper;
        begin
            cbus_ab_i[23:17] = MEM_BASE[23:17];
            cbus_sale_i = 1'b1;
            idle(3);
            cbus_sale_i = 1'b0;
            idle(3);
        end
    endtask

    task automatic target_read(input logic memory_space,
                               input logic [23:0] address,
                               output logic [15:0] value,
                               output logic got_data);
        integer timeout;
        begin
            while (busy) @(negedge c_clk);
            idle(3);
            cbus_ab_i = address;
            cbus_bhe_n_i = 1'b0;
            if (memory_space)
                cbus_mrc_n_i = 1'b0;
            else
                cbus_ior_n_i = 1'b0;
            timeout = 0;
            got_data = 1'b0;
            value = 16'h0000;
            while (!got_data && timeout < 220) begin
                @(negedge c_clk);
                if (cbus_db_oe_req) begin
                    got_data = 1'b1;
                    value = cbus_db_o;
                end
                timeout = timeout + 1;
            end
            if (memory_space)
                cbus_mrc_n_i = 1'b1;
            else
                cbus_ior_n_i = 1'b1;
            if (got_data) begin
                #2;
                check(cbus_db_oe_req, "top read hold was too short");
            end
            while (busy) @(negedge c_clk);
            idle(3);
        end
    endtask

    task automatic memory_write(input logic [23:0] address,
                                input logic [15:0] value,
                                input logic qualify);
        integer timeout;
        begin
            while (busy) @(negedge c_clk);
            idle(3);
            cbus_ab_i = address;
            cbus_bhe_n_i = 1'b0;
            cbus_db_i = value;
            cbus_mwc_n_i = 1'b0;
            idle(3);
            if (qualify)
                cbus_mwe_n_i = 1'b0;
            timeout = 0;
            while (timeout < 100) begin
                @(negedge c_clk);
                timeout = timeout + 1;
            end
            cbus_mwe_n_i = 1'b1;
            cbus_mwc_n_i = 1'b1;
            while (busy) @(negedge c_clk);
            idle(3);
        end
    endtask

    always @(posedge c_clk) begin
        check(!cbus_ab_oe_req && !cbus_mrc_n_oe_req &&
              !cbus_mwc_n_oe_req && !cbus_mwe_n_oe_req &&
              !lvc_cmd_oe_req,
              "passive memory target requested address/command drive");
        if (!cbus_mwc_n_i || !cbus_mwe_n_i)
            check(!cbus_db_oe_req, "top drove DB during memory write");
    end

    initial begin
        logic [15:0] value;
        logic got_data;

        $dumpfile("tb_cbus_memory_top.vcd");
        $dumpvars(0, tb_cbus_memory_top);
        idle(4);
        rst_n = 1'b1;
        idle(8);

        $display("TEST logical_sale_and_system_target");
        target_read(1'b1, MEM_BASE, value, got_data);
        check(!got_data, "top memory route responded without SALE");
        latch_upper();
        target_read(1'b1, MEM_BASE, value, got_data);
        check(got_data && value == 16'hcb98,
              "top memory route did not reach System CSR ID");
        memory_write(MEM_BASE + 24'h8, 16'h5aa5, 1'b1);
        target_read(1'b1, MEM_BASE + 24'h8, value, got_data);
        check(got_data && value == 16'h5aa5,
              "top memory write/read did not reach System CSR scratch");
        memory_write(MEM_BASE + 24'h8, 16'h1234, 1'b0);
        target_read(1'b1, MEM_BASE + 24'h8, value, got_data);
        check(got_data && value == 16'h5aa5,
              "top MWC-only cycle modified System CSR scratch");

        $display("TEST io_compatibility_and_safe_drives");
        target_read(1'b0, {8'h00, 16'h00d0}, value, got_data);
        check(got_data && value == 16'hcb98,
              "top I/O System CSR route changed with memory enabled");
        check(!timeout_sticky && !invalid_sticky &&
              !backend_error_sticky && !abort_sticky,
              "top memory happy path set a sticky fault");
        check(cbus_ab_o == 24'h000000,
              "passive top address output safe value changed");

        if (failures == 0) begin
            $display("PASS: %0d checks", checks);
            $finish;
        end else begin
            $fatal(1, "FAIL: %0d of %0d checks failed", failures, checks);
        end
    end

endmodule

`default_nettype wire
