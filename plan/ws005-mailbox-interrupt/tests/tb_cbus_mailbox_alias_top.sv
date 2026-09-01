`timescale 1ns/1ps
`default_nettype none

module tb_cbus_mailbox_alias_top;
    logic c_clk = 1'b0, a_clk = 1'b0, rst_n = 1'b0;
    always #5 c_clk = ~c_clk;
    always #7 a_clk = ~a_clk;

    logic [23:0] cbus_ab_i;
    logic [23:0] cbus_ab_o;
    logic cbus_ab_oe_req;
    logic [15:0] cbus_db_i, cbus_db_o;
    logic cbus_db_oe_req;
    logic cbus_ior_n_i, cbus_iow_n_i, cbus_bhe_n_i;
    logic cbus_iordy_oe_req, cbus_irq_assert;
    logic lvc_irq_oe_req;
    logic busy, timeout_sticky, invalid_sticky, backend_error_sticky, abort_sticky;
    logic mailbox_cpu_irq_active, mailbox_host_irq_active;
    integer checks;

    cbus_ip_top #(
        .CBUS_MBX_ENABLE(1'b1),
        .CBUS_MBX_IO_BASE(16'h0200),
        .WAIT_ASSERT_CYCLES(4),
        .CBUS_TIMEOUT_CYCLES(200),
        .AXIL_TIMEOUT_CYCLES(64)
    ) dut (
        .cbus_logic_clk(c_clk), .axi_clk(a_clk), .rst_n(rst_n),
        .platform_ready(1'b1), .guard_status_clear(1'b0), .guard_fault_clear(1'b0),
        .cbus_ab_i(cbus_ab_i), .cbus_ab_o(cbus_ab_o), .cbus_ab_oe_req(cbus_ab_oe_req),
        .cbus_db_i(cbus_db_i), .cbus_db_o(cbus_db_o), .cbus_db_oe_req(cbus_db_oe_req),
        .cbus_ior_n_i(cbus_ior_n_i), .cbus_ior_n_o(), .cbus_ior_n_oe_req(),
        .cbus_iow_n_i(cbus_iow_n_i), .cbus_iow_n_o(), .cbus_iow_n_oe_req(),
        .cbus_mrc_n_i(1'b1), .cbus_mrc_n_o(), .cbus_mrc_n_oe_req(),
        .cbus_mwc_n_i(1'b1), .cbus_mwc_n_o(), .cbus_mwc_n_oe_req(),
        .cbus_mwe_n_i(1'b1), .cbus_mwe_n_o(), .cbus_mwe_n_oe_req(),
        .cbus_bhe_n_i(cbus_bhe_n_i), .cbus_bhe_n_o(), .cbus_bhe_n_oe_req(),
        .cbus_reset_n_i(1'b1), .cbus_power_n_i(1'b1), .cbus_sclk_i(1'b0),
        .cbus_iordy_o(), .cbus_iordy_oe_req(cbus_iordy_oe_req),
        .cbus_irq_assert(cbus_irq_assert), .cbus_dack_n_i(1'b1),
        .cbus_drq_n_assert(), .cbus_word_n_o(), .cbus_word_oe_req(),
        .cbus_dmatc_n_i(1'b1), .cbus_exhrq1_n_assert(), .cbus_exhrq2_n_assert(),
        .cbus_exhla1_n_i(1'b1), .cbus_exhla2_n_i(1'b1), .cbus_sbusrq_i(1'b0),
        .lvc_data_dir_req(), .lvc_data_oe_req(), .lvc_iordy_oe_req(),
        .lvc_irq_oe_req(lvc_irq_oe_req), .lvc_word_oe_req(),
        .lvc_addr_dir_req(), .lvc_addr_oe_req(), .lvc_cmd_dir_req(), .lvc_cmd_oe_req(),
        .busy(busy), .timeout_sticky(timeout_sticky), .invalid_sticky(invalid_sticky),
        .backend_error_sticky(backend_error_sticky), .abort_sticky(abort_sticky),
        .stale_rsp_pulse(), .guard_faulted(), .guard_fault_reset_req(),
        .guard_reject_sticky(), .guard_timeout_sticky(),
        .guard_downstream_error_sticky(), .guard_fault_valid(),
        .guard_fault_code(), .guard_fault_write(), .guard_fault_addr(),
        .mailbox_cpu_irq_active(mailbox_cpu_irq_active),
        .mailbox_host_irq_active(mailbox_host_irq_active)
    );

    task automatic check(input logic condition, input string message);
        begin checks = checks + 1; if (!condition) begin
            $display("FAIL check=%0d %s", checks, message); $fatal(1); end end
    endtask

    task automatic idle(input integer cycles);
        integer i; begin for (i = 0; i < cycles; i = i + 1) @(posedge c_clk); end
    endtask

    task automatic cbus_write(input logic [15:0] address, input logic [15:0] data);
        begin
            cbus_ab_i = {8'h00, address}; cbus_db_i = data;
            cbus_bhe_n_i = 1'b0; cbus_iow_n_i = 1'b0;
            idle(80);
            check(busy, "write remains owned until C-bus strobe release");
            check(!cbus_db_oe_req, "write never enables C-bus data output");
            cbus_iow_n_i = 1'b1; idle(6);
            check(!busy && !cbus_iordy_oe_req, "write releases busy and wait");
        end
    endtask

    task automatic cbus_read(
        input logic [15:0] address,
        input logic [15:0] expected,
        input string message
    );
        integer timeout;
        begin
            cbus_ab_i = {8'h00, address}; cbus_bhe_n_i = 1'b0;
            cbus_ior_n_i = 1'b0; timeout = 0;
            while (!cbus_db_oe_req && timeout < 200) begin
                @(posedge c_clk); timeout = timeout + 1; end
            check(cbus_db_oe_req && cbus_db_o == expected, message);
            cbus_ior_n_i = 1'b1;
            timeout = 0; while (cbus_db_oe_req && timeout < 20) begin
                @(posedge c_clk); timeout = timeout + 1; end
            check(!cbus_db_oe_req, "read returns data bus to High-Z request");
            idle(3);
        end
    endtask

    initial begin
        checks = 0; cbus_ab_i = 24'h0; cbus_db_i = 16'h0;
        cbus_ior_n_i = 1'b1; cbus_iow_n_i = 1'b1; cbus_bhe_n_i = 1'b0;
        idle(4); rst_n = 1'b1; idle(8);

        cbus_read(16'h00d0, 16'hcb98, "System CSR ID is unchanged with alias enabled");
        cbus_write(16'h00d4, 16'h5aa5);
        cbus_read(16'h00d4, 16'h5aa5, "System CSR scratch is unchanged with alias enabled");

        cbus_write(16'h0200, 16'h3344);
        cbus_write(16'h0202, 16'h1122);
        cbus_write(16'h0204, 16'h0001);
        cbus_read(16'h0208, 16'h0001, "H2C FIFO occupancy is visible through alias");
        cbus_read(16'h020a, 16'h0000, "H2C status upper half alias");
        cbus_write(16'h0206, 16'h0001);
        idle(10);
        check(dut.g_mailbox_control.control_subsystem.cpu_pending[0],
              "H2C doorbell reaches logical CPU pending");
        check(!mailbox_cpu_irq_active,
              "CPU IRQ remains masked at reset while pending is retained");

        cbus_write(16'h0218, 16'h0002);
        cbus_read(16'h0218, 16'h0002, "host mask read/write alias");
        cbus_read(16'h0216, 16'h0000, "host pending polling alias");
        cbus_read(16'h021c, 16'h0000, "compound diagnostic status is clean");
        cbus_write(16'h021e, 16'h0007);

        @(negedge a_clk);
        force dut.g_mailbox_control.control_subsystem.guard_faulted = 1'b0;
        repeat (2) @(posedge a_clk);
        @(negedge a_clk);
        force dut.g_mailbox_control.control_subsystem.guard_faulted = 1'b1;
        repeat (2) @(posedge a_clk);
        @(negedge a_clk);
        release dut.g_mailbox_control.control_subsystem.guard_faulted;
        repeat (2) @(posedge a_clk);
        check(dut.g_mailbox_control.control_subsystem.cpu_pending[6],
              "guard fault rising edge reaches CPU event bit 6 once");

        cbus_ab_i = 24'h000300; cbus_ior_n_i = 1'b0; idle(20);
        check(!cbus_db_oe_req && !cbus_iordy_oe_req,
              "nonselected address does not drive data or wait");
        cbus_ior_n_i = 1'b1; idle(4);

        check(!cbus_irq_assert && !lvc_irq_oe_req && !mailbox_host_irq_active,
              "logical mailbox integration never drives physical C-bus IRQ");
        check(!timeout_sticky && !invalid_sticky && !backend_error_sticky && !abort_sticky,
              "integrated alias path completes without target sticky faults");

        $display("PASS tb_cbus_mailbox_alias_top checks=%0d", checks);
        $finish;
    end

    wire unused_ab = ^{cbus_ab_o, cbus_ab_oe_req};
endmodule

`default_nettype wire
