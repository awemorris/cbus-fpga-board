`timescale 1ns/1ps
`default_nettype none

module tb_cbus_axil_bridge;

    localparam logic [15:0] CBUS_BASE = 16'h00d0;
    localparam logic [31:0] AXIL_BASE = 32'h1000_0000;
    localparam integer MAX_BFM_CYCLES = 160;

    logic c_clk = 1'b0;
    logic a_clk = 1'b0;
    logic rst_n = 1'b0;
    logic platform_ready = 1'b0;

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

    logic allow_aw = 1'b1;
    logic allow_w = 1'b1;
    logic allow_ar = 1'b1;
    logic hold_responses = 1'b0;
    logic force_error = 1'b0;
    integer response_delay_cfg = 1;

    logic [31:0] axil_mem [0:3];
    logic aw_captured;
    logic w_captured;
    logic [31:0] awaddr_hold;
    logic [31:0] wdata_hold;
    logic [3:0] wstrb_hold;
    logic [1:0] write_state;
    logic [1:0] read_state;
    logic [31:0] araddr_hold;
    logic read_error_hold;
    integer write_delay;
    integer read_delay;
    integer axi_aw_count = 0;
    integer axi_w_count = 0;
    integer axi_b_count = 0;
    integer axi_ar_count = 0;
    integer axi_r_count = 0;
    integer stale_rsp_count = 0;
    logic [31:0] last_awaddr;
    logic [31:0] last_wdata;
    logic [3:0] last_wstrb;
    logic [31:0] last_araddr;
    logic aw_stalled;
    logic w_stalled;
    logic ar_stalled;
    logic [31:0] stalled_awaddr;
    logic [31:0] stalled_wdata;
    logic [3:0] stalled_wstrb;
    logic [31:0] stalled_araddr;

    integer checks = 0;
    integer failures = 0;

    assign cbus_data = host_data_oe ? host_data_o : 16'hzzzz;
    assign cbus_data = target_data_oe ? target_data_o : 16'hzzzz;

    always #5 c_clk = ~c_clk;
    always #7 a_clk = ~a_clk;

    cbus_target_axil_subsystem #(
        .IO_BASE_ADDR(CBUS_BASE),
        .IO_ADDR_MASK(16'hfff8),
        .AXIL_BASE_ADDR(AXIL_BASE),
        .WAIT_ASSERT_CYCLES(2),
        .TIMEOUT_CYCLES(48),
        .RELEASE_HOLD_CYCLES(1),
        .TAG_WIDTH(8),
        .FIFO_ADDR_WIDTH(2)
    ) dut (
        .c_clk(c_clk),
        .a_clk(a_clk),
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
        .busy(busy),
        .timeout_sticky(timeout_sticky),
        .invalid_sticky(invalid_sticky),
        .backend_error_sticky(backend_error_sticky),
        .abort_sticky(abort_sticky),
        .stale_rsp_pulse(stale_rsp_pulse),
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

    assign awready = rst_n && allow_aw && (write_state == 0) && !aw_captured;
    assign wready = rst_n && allow_w && (write_state == 0) && !w_captured;
    assign arready = rst_n && allow_ar && (read_state == 0);

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
        input logic [1:0] be,
        output logic [15:0] value,
        output logic saw_wait
    );
        integer count;
        logic got_data;
        begin
            wait_idle();
            host_data_oe = 1'b0;
            set_lane(address, be);
            cbus_ior_n = 1'b0;
            saw_wait = 1'b0;
            got_data = 1'b0;
            value = 16'h0000;
            count = 0;
            while (!got_data && count < MAX_BFM_CYCLES) begin
                @(negedge c_clk);
                if (target_iordy_oe)
                    saw_wait = 1'b1;
                if (target_data_oe) begin
                    got_data = 1'b1;
                    value = cbus_data;
                    check(!target_iordy_oe,
                          "read data became valid before IORDY release");
                end
                count = count + 1;
            end
            check(got_data, "read cycle produced no data");
            cbus_ior_n = 1'b1;
            #5;
            check(target_data_oe, "read data hold was below 5ns");
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
            while (!saw_wait && count < MAX_BFM_CYCLES) begin
                @(negedge c_clk);
                if (target_iordy_oe)
                    saw_wait = 1'b1;
                count = count + 1;
            end
            check(saw_wait, "CDC write did not request IORDY wait");
            while (target_iordy_oe && count < MAX_BFM_CYCLES) begin
                @(negedge c_clk);
                count = count + 1;
            end
            check(!target_iordy_oe, "write wait did not terminate");
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
            check(!target_data_oe, "target drove data during I/O write");
        if (stale_rsp_pulse)
            stale_rsp_count = stale_rsp_count + 1;
    end

    always @(posedge a_clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_stalled <= 1'b0;
            w_stalled <= 1'b0;
            ar_stalled <= 1'b0;
            stalled_awaddr <= 32'h0000_0000;
            stalled_wdata <= 32'h0000_0000;
            stalled_wstrb <= 4'b0000;
            stalled_araddr <= 32'h0000_0000;
        end else begin
            if (aw_stalled)
                check(awvalid && awaddr == stalled_awaddr,
                      "AW payload changed while backpressured");
            if (w_stalled)
                check(wvalid && wdata == stalled_wdata &&
                      wstrb == stalled_wstrb,
                      "W payload changed while backpressured");
            if (ar_stalled)
                check(arvalid && araddr == stalled_araddr,
                      "AR payload changed while backpressured");

            aw_stalled <= awvalid && !awready;
            w_stalled <= wvalid && !wready;
            ar_stalled <= arvalid && !arready;
            if (awvalid && !awready)
                stalled_awaddr <= awaddr;
            if (wvalid && !wready) begin
                stalled_wdata <= wdata;
                stalled_wstrb <= wstrb;
            end
            if (arvalid && !arready)
                stalled_araddr <= araddr;
        end
    end

    always_ff @(posedge a_clk or negedge rst_n) begin
        integer byte_index;
        integer word_index;
        if (!rst_n) begin
            axil_mem[0] <= 32'h0000_cb98;
            axil_mem[1] <= 32'h0000_0002;
            axil_mem[2] <= 32'h0000_0000;
            axil_mem[3] <= 32'h0000_0000;
            aw_captured <= 1'b0;
            w_captured <= 1'b0;
            awaddr_hold <= 32'h0000_0000;
            wdata_hold <= 32'h0000_0000;
            wstrb_hold <= 4'b0000;
            write_state <= 0;
            read_state <= 0;
            araddr_hold <= 32'h0000_0000;
            read_error_hold <= 1'b0;
            write_delay <= 0;
            read_delay <= 0;
            bvalid <= 1'b0;
            bresp <= 2'b00;
            rvalid <= 1'b0;
            rdata <= 32'h0000_0000;
            rresp <= 2'b00;
            axi_aw_count <= 0;
            axi_w_count <= 0;
            axi_b_count <= 0;
            axi_ar_count <= 0;
            axi_r_count <= 0;
            last_awaddr <= 32'h0000_0000;
            last_wdata <= 32'h0000_0000;
            last_wstrb <= 4'b0000;
            last_araddr <= 32'h0000_0000;
        end else begin
            if (awvalid && awready) begin
                aw_captured <= 1'b1;
                awaddr_hold <= awaddr;
                last_awaddr <= awaddr;
                axi_aw_count <= axi_aw_count + 1;
            end
            if (wvalid && wready) begin
                w_captured <= 1'b1;
                wdata_hold <= wdata;
                wstrb_hold <= wstrb;
                last_wdata <= wdata;
                last_wstrb <= wstrb;
                axi_w_count <= axi_w_count + 1;
            end

            case (write_state)
                0: begin
                    bvalid <= 1'b0;
                    if (aw_captured && w_captured) begin
                        if (!force_error &&
                            awaddr_hold[31:4] == AXIL_BASE[31:4]) begin
                            word_index = awaddr_hold[3:2];
                            for (byte_index = 0; byte_index < 4;
                                 byte_index = byte_index + 1)
                                if (wstrb_hold[byte_index])
                                    axil_mem[word_index]
                                        [byte_index*8 +: 8] <=
                                        wdata_hold[byte_index*8 +: 8];
                        end
                        bresp <= force_error ? 2'b10 : 2'b00;
                        write_delay <= response_delay_cfg;
                        aw_captured <= 1'b0;
                        w_captured <= 1'b0;
                        write_state <= 1;
                    end
                end
                1: begin
                    if (!hold_responses) begin
                        if (write_delay == 0) begin
                            bvalid <= 1'b1;
                            write_state <= 2;
                        end else begin
                            write_delay <= write_delay - 1;
                        end
                    end
                end
                2: begin
                    if (bvalid && bready) begin
                        bvalid <= 1'b0;
                        axi_b_count <= axi_b_count + 1;
                        write_state <= 0;
                    end
                end
                default: write_state <= 0;
            endcase

            case (read_state)
                0: begin
                    rvalid <= 1'b0;
                    if (arvalid && arready) begin
                        araddr_hold <= araddr;
                        last_araddr <= araddr;
                        read_error_hold <= force_error;
                        read_delay <= response_delay_cfg;
                        axi_ar_count <= axi_ar_count + 1;
                        read_state <= 1;
                    end
                end
                1: begin
                    if (!hold_responses) begin
                        if (read_delay == 0) begin
                            if (araddr_hold[31:4] == AXIL_BASE[31:4])
                                rdata <= axil_mem[araddr_hold[3:2]];
                            else
                                rdata <= 32'hffff_ffff;
                            rresp <= read_error_hold ? 2'b10 : 2'b00;
                            rvalid <= 1'b1;
                            read_state <= 2;
                        end else begin
                            read_delay <= read_delay - 1;
                        end
                    end
                end
                2: begin
                    if (rvalid && rready) begin
                        rvalid <= 1'b0;
                        axi_r_count <= axi_r_count + 1;
                        read_state <= 0;
                    end
                end
                default: read_state <= 0;
            endcase
        end
    end

    initial begin
        logic [15:0] value;
        logic saw_wait;
        integer before_count;

        $dumpfile("tb_cbus_axil_bridge.vcd");
        $dumpvars(0, tb_cbus_axil_bridge);
        $display("SEED=1 (deterministic asynchronous-clock BFM)");

        repeat (4) @(negedge c_clk);
        rst_n = 1'b1;
        repeat (4) @(negedge c_clk);
        platform_ready = 1'b1;
        repeat (6) @(negedge c_clk);

        $display("TEST mapped_reads");
        io_read(CBUS_BASE, 2'b11, value, saw_wait);
        check(value == 16'hcb98, "ID read through AXI mismatch");
        check(saw_wait, "CDC read did not request wait");
        check(last_araddr == AXIL_BASE,
              "ID address was not mapped to AXI base");
        check(arprot == 3'b000 && awprot == 3'b000,
              "AXI protection attributes mismatch");

        io_read(CBUS_BASE + 16'h0002, 2'b11, value, saw_wait);
        check(value == 16'h0002, "version read through AXI mismatch");
        check(last_araddr == AXIL_BASE + 32'h0000_0004,
              "C-bus +2 did not map to AXI +4");

        $display("TEST byte_lanes_and_write_channels");
        io_write(CBUS_BASE + 16'h0004, 2'b11, 16'h1234, saw_wait);
        check(axil_mem[2][15:0] == 16'h1234,
              "16-bit scratch write mismatch");
        check(last_awaddr == AXIL_BASE + 32'h0000_0008,
              "scratch address mapping mismatch");
        check(last_wdata == 32'h0000_1234 && last_wstrb == 4'b0011,
              "16-bit AXI write payload mismatch");

        io_write(CBUS_BASE + 16'h0004, 2'b01, 16'h00aa, saw_wait);
        check(axil_mem[2][15:0] == 16'h12aa,
              "low-byte AXI write mismatch");
        check(last_wstrb == 4'b0001, "low-byte WSTRB mismatch");

        io_write(CBUS_BASE + 16'h0005, 2'b10, 16'hbb00, saw_wait);
        check(axil_mem[2][15:0] == 16'hbbaa,
              "high-byte AXI write mismatch");
        check(last_awaddr == AXIL_BASE + 32'h0000_0008,
              "odd high-byte address mapping mismatch");
        check(last_wstrb == 4'b0010, "high-byte WSTRB mismatch");

        io_read(CBUS_BASE + 16'h0004, 2'b11, value, saw_wait);
        check(value == 16'hbbaa, "scratch readback mismatch");
        io_read(CBUS_BASE + 16'h0004, 2'b01, value, saw_wait);
        check(value[7:0] == 8'haa, "low-byte scratch read mismatch");
        check(last_araddr == AXIL_BASE + 32'h0000_0008,
              "low-byte read address mapping mismatch");
        io_read(CBUS_BASE + 16'h0005, 2'b10, value, saw_wait);
        check(value[15:8] == 8'hbb, "high-byte scratch read mismatch");
        check(last_araddr == AXIL_BASE + 32'h0000_0008,
              "high-byte read address mapping mismatch");

        $display("TEST independent_axi_backpressure");
        before_count = axi_aw_count;
        allow_aw = 1'b0;
        fork
            begin
                repeat (8) @(negedge a_clk);
                allow_aw = 1'b1;
            end
            begin
                io_write(CBUS_BASE + 16'h0004, 2'b11,
                         16'h2468, saw_wait);
            end
        join
        check(axi_aw_count == before_count + 1,
              "AW backpressure duplicated/lost address");
        check(axil_mem[2][15:0] == 16'h2468,
              "AW-backpressured write failed");

        before_count = axi_w_count;
        allow_w = 1'b0;
        fork
            begin
                repeat (7) @(negedge a_clk);
                allow_w = 1'b1;
            end
            begin
                io_write(CBUS_BASE + 16'h0004, 2'b11,
                         16'h1357, saw_wait);
            end
        join
        check(axi_w_count == before_count + 1,
              "W backpressure duplicated/lost data");
        check(axil_mem[2][15:0] == 16'h1357,
              "W-backpressured write failed");

        before_count = axi_ar_count;
        allow_ar = 1'b0;
        fork
            begin
                repeat (9) @(negedge a_clk);
                allow_ar = 1'b1;
            end
            begin
                io_read(CBUS_BASE + 16'h0004, 2'b11,
                        value, saw_wait);
            end
        join
        check(axi_ar_count == before_count + 1,
              "AR backpressure duplicated/lost address");
        check(value == 16'h1357, "AR-backpressured read failed");

        $display("TEST delayed_response");
        response_delay_cfg = 7;
        io_read(CBUS_BASE + 16'h0004, 2'b11, value, saw_wait);
        check(value == 16'h1357 && saw_wait,
              "delayed AXI response failed");
        response_delay_cfg = 1;

        $display("TEST axi_error_mapping");
        force_error = 1'b1;
        io_read(CBUS_BASE + 16'h0002, 2'b11, value, saw_wait);
        check(value == 16'he001, "AXI SLVERR data mapping mismatch");
        check(backend_error_sticky,
              "AXI SLVERR did not set backend error sticky");
        force_error = 1'b0;

        $display("TEST timeout_and_stale_response_quarantine");
        hold_responses = 1'b1;
        io_read(CBUS_BASE, 2'b11, value, saw_wait);
        check(value == 16'hffff, "C-bus timeout fallback mismatch");
        check(timeout_sticky, "C-bus timeout sticky was not set");
        before_count = stale_rsp_count;
        fork
            begin
                repeat (10) @(negedge c_clk);
                hold_responses = 1'b0;
            end
            begin
                io_read(CBUS_BASE + 16'h0004, 2'b11,
                        value, saw_wait);
            end
        join
        check(stale_rsp_count > before_count,
              "late response was not identified as stale");
        check(value == 16'h1357,
              "late response was misapplied to the next request");

        $display("TEST coherent_reset_and_recovery");
        platform_ready = 1'b0;
        #1;
        check(!target_data_oe && !target_iordy_oe,
              "platform gate did not disable C-bus outputs");
        rst_n = 1'b0;
        repeat (4) @(negedge c_clk);
        check(!awvalid && !wvalid && !arvalid,
              "AXI request remained valid during reset");
        rst_n = 1'b1;
        repeat (5) @(negedge c_clk);
        platform_ready = 1'b1;
        repeat (6) @(negedge c_clk);
        io_read(CBUS_BASE + 16'h0002, 2'b11, value, saw_wait);
        check(value == 16'h0002, "read failed after coherent reset");
        check(!timeout_sticky && !backend_error_sticky,
              "reset did not clear bridge sticky status");

        check(axi_aw_count == axi_w_count,
              "accepted AXI AW/W channel counts differ");
        check(axi_b_count == axi_aw_count,
              "AXI write response count mismatch");
        check(axi_r_count == axi_ar_count,
              "AXI read response count mismatch");

        if (failures == 0) begin
            $display("PASS: %0d checks", checks);
            $finish;
        end else begin
            $fatal(1, "FAIL: %0d of %0d checks failed", failures, checks);
        end
    end

endmodule

`default_nettype wire
