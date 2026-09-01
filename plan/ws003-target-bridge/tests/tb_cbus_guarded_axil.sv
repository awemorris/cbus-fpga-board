`timescale 1ns/1ps
`default_nettype none

module tb_cbus_guarded_axil;

    localparam logic [15:0] CBUS_BASE = 16'h00d0;
    localparam logic [31:0] AXIL_BASE = 32'h1000_0000;
    localparam integer MAX_BFM_CYCLES = 160;

    logic c_clk = 1'b0;
    logic a_clk = 1'b0;
    logic rst_n = 1'b0;
    logic platform_ready = 1'b0;
    logic guard_status_clear = 1'b0;
    logic guard_fault_clear = 1'b0;

    logic [15:0] cbus_addr = 16'h0000;
    logic cbus_bhe_n = 1'b1;
    logic cbus_ior_n = 1'b1;
    logic cbus_iow_n = 1'b1;
    logic [15:0] host_data_o = 16'h0000;
    logic host_data_oe = 1'b0;
    tri [15:0] cbus_data;
    logic [15:0] target_data_o;
    logic target_data_oe;
    logic target_iordy_oe;

    logic busy;
    logic timeout_sticky;
    logic invalid_sticky;
    logic backend_error_sticky;
    logic abort_sticky;
    logic stale_rsp_pulse;
    logic guard_faulted;
    logic guard_fault_reset_req;
    logic guard_reject_sticky;
    logic guard_timeout_sticky;
    logic guard_downstream_error_sticky;
    logic guard_fault_valid;
    logic [2:0] guard_fault_code;
    logic guard_fault_write;
    logic [31:0] guard_fault_addr;

    logic [31:0] awaddr;
    logic [2:0] awprot;
    logic awvalid;
    logic awready;
    logic [31:0] wdata;
    logic [3:0] wstrb;
    logic wvalid;
    logic wready;
    logic [1:0] bresp;
    logic bvalid;
    logic bready;
    logic [31:0] araddr;
    logic [2:0] arprot;
    logic arvalid;
    logic arready;
    logic [31:0] rdata;
    logic [1:0] rresp;
    logic rvalid;
    logic rready;

    logic model_rst_n = 1'b0;
    logic allow_aw = 1'b1;
    logic allow_w = 1'b1;
    logic allow_ar = 1'b1;
    logic respond_reads = 1'b1;
    logic aw_seen;
    logic w_seen;
    logic [31:0] awaddr_hold;
    logic [31:0] wdata_hold;
    logic [3:0] wstrb_hold;
    logic [31:0] memory [0:3];
    integer downstream_ar_count = 0;
    integer checks = 0;
    integer failures = 0;

    assign cbus_data = host_data_oe ? host_data_o : 16'hzzzz;
    assign cbus_data = target_data_oe ? target_data_o : 16'hzzzz;
    assign awready = model_rst_n && allow_aw && !aw_seen;
    assign wready = model_rst_n && allow_w && !w_seen;
    assign arready = model_rst_n && allow_ar && !rvalid;

    always #5 c_clk = ~c_clk;
    always #7 a_clk = ~a_clk;

    cbus_target_guarded_axil_subsystem #(
        .IO_BASE_ADDR(CBUS_BASE),
        .IO_ADDR_MASK(16'hfff8),
        .AXIL_BASE_ADDR(AXIL_BASE),
        .AXIL_ALLOW_BASE_ADDR(AXIL_BASE),
        .AXIL_ALLOW_ADDR_MASK(32'hffff_f000),
        .WAIT_ASSERT_CYCLES(2),
        .CBUS_TIMEOUT_CYCLES(60),
        .AXIL_TIMEOUT_CYCLES(8),
        .RELEASE_HOLD_CYCLES(1)
    ) dut (
        .c_clk(c_clk),
        .a_clk(a_clk),
        .rst_n(rst_n),
        .platform_ready(platform_ready),
        .guard_status_clear(guard_status_clear),
        .guard_fault_clear(guard_fault_clear),
        .cbus_addr_i(cbus_addr),
        .cbus_mem_addr_i({8'h00, cbus_addr}),
        .cbus_data_i(cbus_data),
        .cbus_bhe_n_i(cbus_bhe_n),
        .cbus_ior_n_i(cbus_ior_n),
        .cbus_iow_n_i(cbus_iow_n),
        .cbus_sale_i(1'b0),
        .cbus_mrc_n_i(1'b1),
        .cbus_mwc_n_i(1'b1),
        .cbus_mwe_n_i(1'b1),
        .cbus_data_o(target_data_o),
        .cbus_data_oe_req(target_data_oe),
        .cbus_iordy_oe_req(target_iordy_oe),
        .busy(busy),
        .timeout_sticky(timeout_sticky),
        .invalid_sticky(invalid_sticky),
        .backend_error_sticky(backend_error_sticky),
        .abort_sticky(abort_sticky),
        .stale_rsp_pulse(stale_rsp_pulse),
        .guard_faulted(guard_faulted),
        .guard_fault_reset_req(guard_fault_reset_req),
        .guard_reject_sticky(guard_reject_sticky),
        .guard_timeout_sticky(guard_timeout_sticky),
        .guard_downstream_error_sticky(
            guard_downstream_error_sticky),
        .guard_fault_valid(guard_fault_valid),
        .guard_fault_code(guard_fault_code),
        .guard_fault_write(guard_fault_write),
        .guard_fault_addr(guard_fault_addr),
        .m_axil_awaddr(awaddr),
        .m_axil_awprot(awprot),
        .m_axil_awvalid(awvalid),
        .m_axil_awready(awready),
        .m_axil_wdata(wdata),
        .m_axil_wstrb(wstrb),
        .m_axil_wvalid(wvalid),
        .m_axil_wready(wready),
        .m_axil_bresp(bresp),
        .m_axil_bvalid(bvalid),
        .m_axil_bready(bready),
        .m_axil_araddr(araddr),
        .m_axil_arprot(arprot),
        .m_axil_arvalid(arvalid),
        .m_axil_arready(arready),
        .m_axil_rdata(rdata),
        .m_axil_rresp(rresp),
        .m_axil_rvalid(rvalid),
        .m_axil_rready(rready)
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

    task automatic set_lane(
        input logic [15:0] address,
        input logic [1:0] be
    );
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
                @(negedge c_clk);
                count = count + 1;
            end
            check(!busy, "target engine did not return idle");
            repeat (3) @(negedge c_clk);
        end
    endtask

    task automatic io_read(
        input logic [15:0] address,
        output logic [15:0] value,
        output logic saw_wait
    );
        integer count;
        logic got_data;
        begin
            wait_idle();
            host_data_oe = 1'b0;
            set_lane(address, 2'b11);
            cbus_ior_n = 1'b0;
            value = 16'h0000;
            saw_wait = 1'b0;
            got_data = 1'b0;
            count = 0;
            while (!got_data && count < MAX_BFM_CYCLES) begin
                @(negedge c_clk);
                if (target_iordy_oe)
                    saw_wait = 1'b1;
                if (target_data_oe) begin
                    got_data = 1'b1;
                    value = cbus_data;
                    check(!target_iordy_oe,
                          "read data appeared before IORDY release");
                end
                count = count + 1;
            end
            check(got_data, "C-bus read produced no data");
            cbus_ior_n = 1'b1;
            #5;
            check(target_data_oe, "read data hold was below 5ns");
            wait_idle();
        end
    endtask

    task automatic io_write(
        input logic [15:0] address,
        input logic [15:0] value
    );
        integer count;
        logic saw_wait;
        begin
            wait_idle();
            set_lane(address, 2'b11);
            host_data_o = value;
            host_data_oe = 1'b1;
            cbus_iow_n = 1'b0;
            count = 0;
            saw_wait = 1'b0;
            while (!saw_wait && count < MAX_BFM_CYCLES) begin
                @(negedge c_clk);
                if (target_iordy_oe)
                    saw_wait = 1'b1;
                count = count + 1;
            end
            check(saw_wait, "guarded write did not request wait");
            while (target_iordy_oe && count < MAX_BFM_CYCLES) begin
                @(negedge c_clk);
                count = count + 1;
            end
            check(!target_iordy_oe, "guarded write wait did not finish");
            cbus_iow_n = 1'b1;
            repeat (3) @(negedge c_clk);
            host_data_oe = 1'b0;
            wait_idle();
        end
    endtask

    always @(posedge c_clk) begin
        if (host_data_oe && target_data_oe)
            check(1'b0, "C-bus data contention detected");
        if ((host_data_oe || target_data_oe) &&
            (^cbus_data === 1'bx))
            check(1'b0, "X detected on driven C-bus data");
        if (!rst_n || !platform_ready) begin
            check(!target_data_oe,
                  "data OE active while reset/not-ready");
            check(!target_iordy_oe,
                  "IORDY OE active while reset/not-ready");
        end
        if (!cbus_iow_n)
            check(!target_data_oe, "target drove data during write");
    end

    always_ff @(posedge a_clk or negedge model_rst_n) begin
        integer byte_index;
        integer word_index;
        if (!model_rst_n) begin
            memory[0] <= 32'h0000_cb98;
            memory[1] <= 32'h0000_0003;
            memory[2] <= 32'h0000_0000;
            memory[3] <= 32'h0000_0000;
            aw_seen <= 1'b0;
            w_seen <= 1'b0;
            awaddr_hold <= 32'h0000_0000;
            wdata_hold <= 32'h0000_0000;
            wstrb_hold <= 4'b0000;
            bvalid <= 1'b0;
            bresp <= 2'b00;
            rvalid <= 1'b0;
            rdata <= 32'h0000_0000;
            rresp <= 2'b00;
            downstream_ar_count <= 0;
        end else begin
            if (awvalid && awready) begin
                aw_seen <= 1'b1;
                awaddr_hold <= awaddr;
            end
            if (wvalid && wready) begin
                w_seen <= 1'b1;
                wdata_hold <= wdata;
                wstrb_hold <= wstrb;
            end
            if (aw_seen && w_seen && !bvalid) begin
                word_index = awaddr_hold[3:2];
                for (byte_index = 0; byte_index < 4;
                     byte_index = byte_index + 1)
                    if (wstrb_hold[byte_index])
                        memory[word_index][byte_index*8 +: 8] <=
                            wdata_hold[byte_index*8 +: 8];
                bresp <= 2'b00;
                bvalid <= 1'b1;
            end
            if (bvalid && bready) begin
                bvalid <= 1'b0;
                aw_seen <= 1'b0;
                w_seen <= 1'b0;
            end

            if (arvalid && arready) begin
                downstream_ar_count <= downstream_ar_count + 1;
                if (respond_reads) begin
                    rdata <= memory[araddr[3:2]];
                    rresp <= 2'b00;
                    rvalid <= 1'b1;
                end
            end
            if (rvalid && rready)
                rvalid <= 1'b0;
        end
    end

    initial begin
        logic [15:0] value;
        logic saw_wait;
        integer before_ar;

        $dumpfile("tb_cbus_guarded_axil.vcd");
        $dumpvars(0, tb_cbus_guarded_axil);

        repeat (4) @(negedge c_clk);
        rst_n = 1'b1;
        model_rst_n = 1'b1;
        repeat (4) @(negedge c_clk);
        platform_ready = 1'b1;
        repeat (6) @(negedge c_clk);

        $display("TEST normal_guarded_path");
        io_read(CBUS_BASE, value, saw_wait);
        check(value == 16'hcb98 && saw_wait,
              "guarded ID read failed");
        io_write(CBUS_BASE + 16'h0004, 16'h5aa5);
        io_read(CBUS_BASE + 16'h0004, value, saw_wait);
        check(value == 16'h5aa5, "guarded scratch readback failed");
        check(!guard_faulted && !guard_fault_valid,
              "normal path created guard fault");

        $display("TEST guard_timeout_precedes_cbus_timeout");
        respond_reads = 1'b0;
        before_ar = downstream_ar_count;
        io_read(CBUS_BASE + 16'h0002, value, saw_wait);
        check(value == 16'he001 && saw_wait,
              "guard timeout did not become C-bus backend error");
        check(downstream_ar_count == before_ar + 1,
              "guard timeout read was not accepted downstream");
        check(guard_faulted && guard_fault_reset_req &&
              guard_timeout_sticky && guard_fault_valid &&
              guard_fault_code == 3'd3 && !guard_fault_write,
              "guard response-timeout record mismatch");
        check(guard_fault_addr == AXIL_BASE + 32'h0000_0004,
              "guard timeout address record mismatch");
        check(backend_error_sticky && !timeout_sticky,
              "guard did not respond before C-bus timeout");

        $display("TEST faulted_local_error");
        before_ar = downstream_ar_count;
        io_read(CBUS_BASE, value, saw_wait);
        check(value == 16'he001,
              "faulted guard did not return local error");
        check(downstream_ar_count == before_ar,
              "faulted C-bus request reached downstream");

        $display("TEST subordinate_reset_clear_and_recovery");
        allow_aw = 1'b0;
        allow_w = 1'b0;
        allow_ar = 1'b0;
        model_rst_n = 1'b0;
        repeat (3) @(negedge a_clk);
        model_rst_n = 1'b1;
        repeat (2) @(negedge a_clk);
        guard_fault_clear = 1'b1;
        @(negedge a_clk);
        guard_fault_clear = 1'b0;
        guard_status_clear = 1'b1;
        @(negedge a_clk);
        guard_status_clear = 1'b0;
        repeat (2) @(negedge a_clk);
        allow_aw = 1'b1;
        allow_w = 1'b1;
        allow_ar = 1'b1;
        respond_reads = 1'b1;
        check(!guard_faulted && !guard_fault_reset_req,
              "guard did not clear after subordinate reset");
        io_read(CBUS_BASE + 16'h0002, value, saw_wait);
        check(value == 16'h0003,
              "guarded path did not recover after fault clear");
        check(!guard_timeout_sticky && !guard_fault_valid,
              "guard status clear failed");

        $display("TEST coherent_system_reset");
        platform_ready = 1'b0;
        rst_n = 1'b0;
        model_rst_n = 1'b0;
        repeat (4) @(negedge c_clk);
        check(!target_data_oe && !target_iordy_oe,
              "system reset did not gate C-bus outputs");
        rst_n = 1'b1;
        model_rst_n = 1'b1;
        repeat (4) @(negedge c_clk);
        platform_ready = 1'b1;
        repeat (6) @(negedge c_clk);
        io_read(CBUS_BASE, value, saw_wait);
        check(value == 16'hcb98, "post-reset ID read failed");
        check(!timeout_sticky && !backend_error_sticky &&
              !guard_timeout_sticky && !guard_faulted,
              "coherent reset did not clear fault state");

        if (failures == 0) begin
            $display("PASS: %0d checks", checks);
            $finish;
        end else begin
            $fatal(1, "FAIL: %0d of %0d checks failed", failures, checks);
        end
    end

endmodule

`default_nettype wire
