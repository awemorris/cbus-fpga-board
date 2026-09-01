`timescale 1ns/1ps
`default_nettype none

module tb_portable_board_tops;
    logic board_clk = 1'b0;
    always #5 board_clk = ~board_clk;

    logic [23:0] host_ab;
    logic [15:0] host_db;
    logic host_db_drive;
    logic host_ior_n, host_iow_n, host_mrc_n, host_mwc_n, host_mwe_n, host_bhe_n;
    logic cbus_reset_n, cbus_power_n, cbus_sclk;
    logic cbus_dack_selected_n, cbus_dmatc_n;
    logic cbus_b42_exhla1_n, cbus_b46_exhla2_n, cbus_b48_sbusrq;

    wire [23:0] p_ab, m_ab;
    wire [15:0] p_db, m_db;
    wire p_ior_n, m_ior_n, p_iow_n, m_iow_n, p_mrc_n, m_mrc_n;
    wire p_mwc_n, m_mwc_n, p_mwe_n, m_mwe_n, p_bhe_n, m_bhe_n;
    wire p_iordy, m_iordy, p_irq, m_irq, p_drq, m_drq, p_word, m_word;
    wire p_ex1, m_ex1, p_ex2, m_ex2;
    wire [8:0] p_lvc, m_lvc;
    wire [8:0] safe_default_lvc;

    assign p_ab = host_ab; assign m_ab = host_ab;
    assign p_db = host_db_drive ? host_db : 16'hzzzz;
    assign m_db = host_db_drive ? host_db : 16'hzzzz;
    assign p_ior_n = host_ior_n; assign m_ior_n = host_ior_n;
    assign p_iow_n = host_iow_n; assign m_iow_n = host_iow_n;
    assign p_mrc_n = host_mrc_n; assign m_mrc_n = host_mrc_n;
    assign p_mwc_n = host_mwc_n; assign m_mwc_n = host_mwc_n;
    assign p_mwe_n = host_mwe_n; assign m_mwe_n = host_mwe_n;
    assign p_bhe_n = host_bhe_n; assign m_bhe_n = host_bhe_n;

    tang_primer20k_top #(.ENABLE_RAW_CLOCK_TEST_ONLY(1'b1)) primer (
        .board_clk(board_clk), .cbus_ab(p_ab), .cbus_db(p_db),
        .cbus_ior_n(p_ior_n), .cbus_iow_n(p_iow_n), .cbus_mrc_n(p_mrc_n),
        .cbus_mwc_n(p_mwc_n), .cbus_mwe_n(p_mwe_n), .cbus_bhe_n(p_bhe_n),
        .cbus_reset_n(cbus_reset_n), .cbus_power_n(cbus_power_n), .cbus_sclk(cbus_sclk),
        .cbus_iordy(p_iordy), .cbus_irq_selected(p_irq),
        .cbus_dack_selected_n(cbus_dack_selected_n), .cbus_drq_selected_n(p_drq),
        .cbus_word_n(p_word), .cbus_dmatc_n(cbus_dmatc_n),
        .cbus_b40_exhrq1_n(p_ex1), .cbus_b47_exhrq2_n(p_ex2),
        .cbus_b42_exhla1_n(cbus_b42_exhla1_n), .cbus_b46_exhla2_n(cbus_b46_exhla2_n),
        .cbus_b48_sbusrq(cbus_b48_sbusrq),
        .lvc_data_dir(p_lvc[0]), .lvc_data_oe_n(p_lvc[1]), .lvc_iordy_oe_n(p_lvc[2]),
        .lvc_irq_oe_n(p_lvc[3]), .lvc_word_oe_n(p_lvc[4]), .lvc_addr_dir(p_lvc[5]),
        .lvc_addr_oe_n(p_lvc[6]), .lvc_cmd_dir(p_lvc[7]), .lvc_cmd_oe_n(p_lvc[8])
    );

    tang_mega138k_top #(.ENABLE_RAW_CLOCK_TEST_ONLY(1'b1)) mega (
        .board_clk(board_clk), .cbus_ab(m_ab), .cbus_db(m_db),
        .cbus_ior_n(m_ior_n), .cbus_iow_n(m_iow_n), .cbus_mrc_n(m_mrc_n),
        .cbus_mwc_n(m_mwc_n), .cbus_mwe_n(m_mwe_n), .cbus_bhe_n(m_bhe_n),
        .cbus_reset_n(cbus_reset_n), .cbus_power_n(cbus_power_n), .cbus_sclk(cbus_sclk),
        .cbus_iordy(m_iordy), .cbus_irq_selected(m_irq),
        .cbus_dack_selected_n(cbus_dack_selected_n), .cbus_drq_selected_n(m_drq),
        .cbus_word_n(m_word), .cbus_dmatc_n(cbus_dmatc_n),
        .cbus_b40_exhrq1_n(m_ex1), .cbus_b47_exhrq2_n(m_ex2),
        .cbus_b42_exhla1_n(cbus_b42_exhla1_n), .cbus_b46_exhla2_n(cbus_b46_exhla2_n),
        .cbus_b48_sbusrq(cbus_b48_sbusrq),
        .lvc_data_dir(m_lvc[0]), .lvc_data_oe_n(m_lvc[1]), .lvc_iordy_oe_n(m_lvc[2]),
        .lvc_irq_oe_n(m_lvc[3]), .lvc_word_oe_n(m_lvc[4]), .lvc_addr_dir(m_lvc[5]),
        .lvc_addr_oe_n(m_lvc[6]), .lvc_cmd_dir(m_lvc[7]), .lvc_cmd_oe_n(m_lvc[8])
    );

    tang_primer20k_top safe_default (
        .board_clk(board_clk), .cbus_ab(), .cbus_db(),
        .cbus_ior_n(), .cbus_iow_n(), .cbus_mrc_n(), .cbus_mwc_n(), .cbus_mwe_n(), .cbus_bhe_n(),
        .cbus_reset_n(1'b1), .cbus_power_n(1'b1), .cbus_sclk(1'b0),
        .cbus_iordy(), .cbus_irq_selected(), .cbus_dack_selected_n(1'b1),
        .cbus_drq_selected_n(), .cbus_word_n(), .cbus_dmatc_n(1'b1),
        .cbus_b40_exhrq1_n(), .cbus_b47_exhrq2_n(),
        .cbus_b42_exhla1_n(1'b1), .cbus_b46_exhla2_n(1'b1), .cbus_b48_sbusrq(1'b0),
        .lvc_data_dir(safe_default_lvc[0]), .lvc_data_oe_n(safe_default_lvc[1]),
        .lvc_iordy_oe_n(safe_default_lvc[2]), .lvc_irq_oe_n(safe_default_lvc[3]),
        .lvc_word_oe_n(safe_default_lvc[4]), .lvc_addr_dir(safe_default_lvc[5]),
        .lvc_addr_oe_n(safe_default_lvc[6]), .lvc_cmd_dir(safe_default_lvc[7]),
        .lvc_cmd_oe_n(safe_default_lvc[8])
    );

    integer checks;
    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL check=%0d: %s p_db=%h m_db=%h p_lvc=%b m_lvc=%b", checks, message, p_db, m_db, p_lvc, m_lvc);
                $fatal(1);
            end
        end
    endtask

    task automatic idle_cycles(input integer count);
        integer i;
        begin for (i = 0; i < count; i = i + 1) @(posedge board_clk); end
    endtask

    task automatic cbus_read(
        input logic [15:0] address,
        input logic [15:0] expected,
        input string message
    );
        begin
            host_ab = {8'h00, address};
            host_db_drive = 1'b0;
            host_ior_n = 1'b0;
            fork
                begin
                    wait (!p_lvc[1]);
                    #1;
                    check(!m_lvc[1], "selected read OE equivalence");
                    check(p_db === m_db, "selected read data equivalence");
                    check(p_db === expected, message);
                end
                begin idle_cycles(100); $fatal(1, "selected read timed out"); end
            join_any
            disable fork;
            host_ior_n = 1'b1;
            fork
                begin wait (p_lvc[1] && m_lvc[1]); end
                begin idle_cycles(20); $fatal(1, "read release timed out"); end
            join_any
            disable fork;
            check(p_lvc[1] && m_lvc[1], "read release returns High-Z");
            idle_cycles(2);
        end
    endtask

    task automatic cbus_write(input logic [15:0] address, input logic [15:0] data);
        begin
            host_ab = {8'h00, address};
            host_db = data;
            host_db_drive = 1'b1;
            host_iow_n = 1'b0;
            idle_cycles(16);
            check(p_lvc === m_lvc, "selected write board equivalence");
            check(p_lvc[1] && m_lvc[1], "write never drives data");
            host_iow_n = 1'b1;
            host_db_drive = 1'b0;
            idle_cycles(6);
        end
    endtask

    initial begin
        checks = 0;
        host_ab = 24'h000000; host_db = 16'h0000; host_db_drive = 1'b0;
        host_ior_n = 1'b1; host_iow_n = 1'b1; host_mrc_n = 1'b1;
        host_mwc_n = 1'b1; host_mwe_n = 1'b1; host_bhe_n = 1'b0;
        cbus_reset_n = 1'b0; cbus_power_n = 1'b1; cbus_sclk = 1'b0;
        cbus_dack_selected_n = 1'b1; cbus_dmatc_n = 1'b1;
        cbus_b42_exhla1_n = 1'b1; cbus_b46_exhla2_n = 1'b1; cbus_b48_sbusrq = 1'b0;
        idle_cycles(4);
        check({safe_default_lvc[8], safe_default_lvc[6], safe_default_lvc[4:1]} === 6'b111111,
              "production-default wrapper keeps every LVC OE disabled");
        check({safe_default_lvc[7], safe_default_lvc[5], safe_default_lvc[0]} === 3'b000,
              "production-default wrapper keeps receiver directions");
        check({p_lvc[8], p_lvc[6], p_lvc[4:1]} === 6'b111111 &&
              {m_lvc[8], m_lvc[6], m_lvc[4:1]} === 6'b111111,
              "reset forces all active-low OEs high");
        check({p_lvc[7], p_lvc[5], p_lvc[0]} === 3'b000 &&
              {m_lvc[7], m_lvc[5], m_lvc[0]} === 3'b000,
              "reset forces receiver directions");

        cbus_reset_n = 1'b1;
        idle_cycles(6);
        check(p_lvc === m_lvc, "idle board equivalence");
        check(p_lvc[1] && p_lvc[2] && p_lvc[3] && p_lvc[4] && p_lvc[6] && p_lvc[8], "idle High-Z");

        host_ab = 24'h000100;
        host_ior_n = 1'b0;
        idle_cycles(8);
        check(p_lvc === m_lvc, "nonselected board equivalence");
        check(p_lvc[1] && m_lvc[1], "nonselected data High-Z");
        host_ior_n = 1'b1;
        idle_cycles(4);

        cbus_read(16'h00d0, 16'hcb98, "System CSR product ID");
        cbus_read(16'h00d2, 16'h0002, "System CSR ABI version");
        cbus_read(16'h00d6, 16'h0000, "System CSR clean status");

        host_bhe_n = 1'b0;
        cbus_write(16'h00d4, 16'h55aa);
        host_bhe_n = 1'b1;
        cbus_write(16'h00d4, 16'h0033);
        host_bhe_n = 1'b0;
        cbus_write(16'h00d5, 16'hcc00);
        cbus_read(16'h00d4, 16'hcc33, "System CSR scratch byte lanes");

        cbus_write(16'h00d0, 16'hffff);
        idle_cycles(4);
        cbus_read(16'h00d6, 16'h1384, "System CSR backend/guard first-fault status");

        cbus_power_n = 1'b0;
        #0;
        check({p_lvc[8], p_lvc[6], p_lvc[4:1]} === 6'b111111 &&
              {m_lvc[8], m_lvc[6], m_lvc[4:1]} === 6'b111111,
              "power-good withdrawal immediately disables OEs");

        $display("PASS tb_portable_board_tops checks=%0d", checks);
        $finish;
    end
endmodule

`default_nettype wire
