`timescale 1ns/1ps
`default_nettype none

module tb_cbus_memory_axil;

    localparam logic [15:0] IO_BASE = 16'h00d0;
    localparam logic [23:0] MEM_BASE = 24'ha10000;
    localparam logic [31:0] AXIL_BASE = 32'h1000_0000;
    localparam logic [31:0] AXIL_MEM_BASE = 32'h1000_0800;
    localparam integer MAX_CYCLES = 180;

    logic c_clk = 1'b0;
    logic a_clk = 1'b0;
    logic rst_n = 1'b0;
    logic platform_ready = 1'b0;
    logic [23:0] cbus_addr = 24'h000000;
    logic [15:0] cbus_data_i = 16'h0000;
    logic cbus_bhe_n = 1'b1;
    logic cbus_ior_n = 1'b1;
    logic cbus_iow_n = 1'b1;
    logic cbus_sale = 1'b0;
    logic cbus_mrc_n = 1'b1;
    logic cbus_mwc_n = 1'b1;
    logic cbus_mwe_n = 1'b1;
    logic [15:0] cbus_data_o;
    logic cbus_data_oe;
    logic cbus_iordy_oe;
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
    logic [1:0] bresp = 2'b00;
    logic bvalid = 1'b0;
    logic bready;
    logic [31:0] araddr;
    logic [2:0] arprot;
    logic arvalid;
    logic arready;
    logic [31:0] rdata = 32'h00000000;
    logic [1:0] rresp = 2'b00;
    logic rvalid = 1'b0;
    logic rready;

    logic allow_aw = 1'b1;
    logic allow_w = 1'b1;
    logic allow_ar = 1'b1;
    logic force_error = 1'b0;
    logic hold_read_response = 1'b0;
    logic aw_held = 1'b0;
    logic w_held = 1'b0;
    logic [31:0] awaddr_held;
    logic [31:0] wdata_held;
    logic [3:0] wstrb_held;
    logic read_pending = 1'b0;
    logic [31:0] araddr_held;
    integer read_countdown = 0;
    integer read_delay = 2;
    logic [31:0] memory [0:63];
    integer axi_aw_count = 0;
    integer axi_w_count = 0;
    integer axi_ar_count = 0;
    integer axi_b_count = 0;
    integer axi_r_count = 0;
    integer stale_count = 0;
    logic [31:0] last_awaddr;
    logic [31:0] last_wdata;
    logic [3:0] last_wstrb;
    logic [31:0] last_araddr;
    integer checks = 0;
    integer failures = 0;

    always #5 c_clk = ~c_clk;
    always #7 a_clk = ~a_clk;

    cbus_target_axil_subsystem #(
        .IO_BASE_ADDR(IO_BASE),
        .IO_ADDR_MASK(16'hfff8),
        .CBUS_MEM_ENABLE(1'b1),
        .CBUS_MEM_BASE(MEM_BASE),
        .CBUS_MEM_ADDR_MASK(24'hffff00),
        .AXIL_MEM_TARGET_BASE(AXIL_MEM_BASE),
        .AXIL_BASE_ADDR(AXIL_BASE),
        .WAIT_ASSERT_CYCLES(2),
        .TIMEOUT_CYCLES(55),
        .RELEASE_HOLD_CYCLES(1),
        .TAG_WIDTH(8),
        .FIFO_ADDR_WIDTH(2)
    ) dut (
        .c_clk(c_clk), .a_clk(a_clk), .rst_n(rst_n),
        .platform_ready(platform_ready),
        .cbus_addr_i(cbus_addr[15:0]),
        .cbus_mem_addr_i(cbus_addr), .cbus_data_i(cbus_data_i),
        .cbus_bhe_n_i(cbus_bhe_n), .cbus_ior_n_i(cbus_ior_n),
        .cbus_iow_n_i(cbus_iow_n), .cbus_sale_i(cbus_sale),
        .cbus_mrc_n_i(cbus_mrc_n), .cbus_mwc_n_i(cbus_mwc_n),
        .cbus_mwe_n_i(cbus_mwe_n),
        .cbus_data_o(cbus_data_o), .cbus_data_oe_req(cbus_data_oe),
        .cbus_iordy_oe_req(cbus_iordy_oe), .busy(busy),
        .timeout_sticky(timeout_sticky),
        .invalid_sticky(invalid_sticky),
        .backend_error_sticky(backend_error_sticky),
        .abort_sticky(abort_sticky), .stale_rsp_pulse(stale_rsp_pulse),
        .m_axil_awaddr(awaddr), .m_axil_awprot(awprot),
        .m_axil_awvalid(awvalid), .m_axil_awready(awready),
        .m_axil_wdata(wdata), .m_axil_wstrb(wstrb),
        .m_axil_wvalid(wvalid), .m_axil_wready(wready),
        .m_axil_bresp(bresp), .m_axil_bvalid(bvalid),
        .m_axil_bready(bready), .m_axil_araddr(araddr),
        .m_axil_arprot(arprot), .m_axil_arvalid(arvalid),
        .m_axil_arready(arready), .m_axil_rdata(rdata),
        .m_axil_rresp(rresp), .m_axil_rvalid(rvalid),
        .m_axil_rready(rready)
    );

    assign awready = rst_n && allow_aw && !aw_held;
    assign wready = rst_n && allow_w && !w_held;
    assign arready = rst_n && allow_ar && !read_pending && !rvalid;

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (!condition) begin
                failures = failures + 1;
                $display("FAIL @ %0t: %s", $time, message);
            end
        end
    endtask

    task automatic wait_idle;
        integer count;
        begin
            count = 0;
            while (busy && count < MAX_CYCLES) begin
                @(negedge c_clk);
                count = count + 1;
            end
            check(!busy, "combined target did not return idle");
            repeat (3) @(negedge c_clk);
        end
    endtask

    task automatic latch_upper(input logic [6:0] upper);
        begin
            cbus_addr[23:17] = upper;
            cbus_sale = 1'b1;
            repeat (3) @(negedge c_clk);
            cbus_sale = 1'b0;
            repeat (3) @(negedge c_clk);
        end
    endtask

    task automatic set_lane(input logic [23:0] address,
                            input logic [1:0] be);
        begin
            cbus_addr = {address[23:1], ~be[0]};
            cbus_bhe_n = ~be[1];
        end
    endtask

    task automatic bus_read(input logic memory_space,
                            input logic [23:0] address,
                            input logic [1:0] be,
                            output logic [15:0] value,
                            output logic got_data,
                            output logic saw_wait);
        integer count;
        begin
            wait_idle();
            set_lane(address, be);
            value = 16'h0000;
            got_data = 1'b0;
            saw_wait = 1'b0;
            if (memory_space)
                cbus_mrc_n = 1'b0;
            else
                cbus_ior_n = 1'b0;
            count = 0;
            while (!got_data && count < MAX_CYCLES) begin
                @(negedge c_clk);
                if (cbus_iordy_oe)
                    saw_wait = 1'b1;
                if (cbus_data_oe) begin
                    got_data = 1'b1;
                    value = cbus_data_o;
                    check(!cbus_iordy_oe,
                          "read data appeared before IORDY release");
                end
                count = count + 1;
            end
            if (memory_space)
                cbus_mrc_n = 1'b1;
            else
                cbus_ior_n = 1'b1;
            #2;
            if (got_data)
                check(cbus_data_oe, "read data hold was too short");
            wait_idle();
        end
    endtask

    task automatic memory_write(input logic [23:0] address,
                                input logic [1:0] be,
                                input logic [15:0] value,
                                output logic saw_wait);
        integer count;
        begin
            wait_idle();
            set_lane(address, be);
            cbus_data_i = value;
            cbus_mwc_n = 1'b0;
            repeat (3) @(negedge c_clk);
            cbus_mwe_n = 1'b0;
            saw_wait = 1'b0;
            count = 0;
            while (!cbus_iordy_oe && count < MAX_CYCLES) begin
                @(negedge c_clk);
                count = count + 1;
            end
            saw_wait = cbus_iordy_oe;
            while (cbus_iordy_oe && count < MAX_CYCLES) begin
                @(negedge c_clk);
                count = count + 1;
            end
            check(count < MAX_CYCLES, "memory write wait did not finish");
            cbus_mwe_n = 1'b1;
            cbus_mwc_n = 1'b1;
            wait_idle();
        end
    endtask

    function automatic [31:0] read_model(input logic [31:0] address);
        integer index;
        begin
            if (address == AXIL_BASE)
                read_model = 32'h0000_cb98;
            else if (address == AXIL_BASE + 32'h4)
                read_model = 32'h0000_0004;
            else if ((address >= AXIL_MEM_BASE) &&
                     (address < AXIL_MEM_BASE + 32'h100)) begin
                index = (address - AXIL_MEM_BASE) >> 2;
                read_model = memory[index];
            end else begin
                read_model = 32'hdead_dead;
            end
        end
    endfunction

    always_ff @(posedge a_clk or negedge rst_n) begin
        integer byte_index;
        integer word_index;
        if (!rst_n) begin
            aw_held <= 1'b0;
            w_held <= 1'b0;
            awaddr_held <= 32'h00000000;
            wdata_held <= 32'h00000000;
            wstrb_held <= 4'b0000;
            bvalid <= 1'b0;
            bresp <= 2'b00;
            read_pending <= 1'b0;
            araddr_held <= 32'h00000000;
            read_countdown <= 0;
            rvalid <= 1'b0;
            rdata <= 32'h00000000;
            rresp <= 2'b00;
            axi_aw_count <= 0;
            axi_w_count <= 0;
            axi_ar_count <= 0;
            axi_b_count <= 0;
            axi_r_count <= 0;
            last_awaddr <= 32'h00000000;
            last_wdata <= 32'h00000000;
            last_wstrb <= 4'b0000;
            last_araddr <= 32'h00000000;
        end else begin
            if (awvalid && awready) begin
                aw_held <= 1'b1;
                awaddr_held <= awaddr;
                last_awaddr <= awaddr;
                axi_aw_count <= axi_aw_count + 1;
            end
            if (wvalid && wready) begin
                w_held <= 1'b1;
                wdata_held <= wdata;
                wstrb_held <= wstrb;
                last_wdata <= wdata;
                last_wstrb <= wstrb;
                axi_w_count <= axi_w_count + 1;
            end
            if (aw_held && w_held && !bvalid) begin
                if ((awaddr_held >= AXIL_MEM_BASE) &&
                    (awaddr_held < AXIL_MEM_BASE + 32'h100)) begin
                    word_index = (awaddr_held - AXIL_MEM_BASE) >> 2;
                    for (byte_index = 0; byte_index < 4;
                         byte_index = byte_index + 1)
                        if (wstrb_held[byte_index])
                            memory[word_index][byte_index*8 +: 8] <=
                                wdata_held[byte_index*8 +: 8];
                end
                bresp <= force_error ? 2'b10 : 2'b00;
                bvalid <= 1'b1;
            end
            if (bvalid && bready) begin
                bvalid <= 1'b0;
                aw_held <= 1'b0;
                w_held <= 1'b0;
                axi_b_count <= axi_b_count + 1;
            end

            if (arvalid && arready) begin
                read_pending <= 1'b1;
                araddr_held <= araddr;
                last_araddr <= araddr;
                read_countdown <= read_delay;
                axi_ar_count <= axi_ar_count + 1;
            end else if (read_pending && !hold_read_response) begin
                if (read_countdown == 0) begin
                    rdata <= read_model(araddr_held);
                    rresp <= force_error ? 2'b10 : 2'b00;
                    rvalid <= 1'b1;
                    read_pending <= 1'b0;
                end else begin
                    read_countdown <= read_countdown - 1;
                end
            end
            if (rvalid && rready) begin
                rvalid <= 1'b0;
                axi_r_count <= axi_r_count + 1;
            end
        end
    end

    always @(posedge c_clk) begin
        if (stale_rsp_pulse)
            stale_count = stale_count + 1;
        if (!rst_n || !platform_ready)
            check(!cbus_data_oe && !cbus_iordy_oe,
                  "combined output active while reset/not-ready");
        if (!cbus_iow_n || !cbus_mwc_n || !cbus_mwe_n)
            check(!cbus_data_oe, "combined target drove DB during write");
    end

    initial begin
        logic [15:0] value;
        logic got_data;
        logic saw_wait;
        integer before_count;

        $dumpfile("tb_cbus_memory_axil.vcd");
        $dumpvars(0, tb_cbus_memory_axil);
        memory[0] = 32'h4433_2211;
        memory[1] = 32'h8877_6655;

        repeat (4) @(negedge c_clk);
        rst_n = 1'b1;
        repeat (4) @(negedge c_clk);
        platform_ready = 1'b1;
        repeat (6) @(negedge c_clk);
        latch_upper(7'h50);

        $display("TEST memory_read_mapping_and_lanes");
        bus_read(1'b1, MEM_BASE, 2'b11, value, got_data, saw_wait);
        check(got_data && value == 16'h2211 && saw_wait,
              "memory low-half read mapping failed");
        check(last_araddr == AXIL_MEM_BASE,
              "memory low-half AXI address mismatch");
        bus_read(1'b1, MEM_BASE + 24'h2, 2'b11,
                 value, got_data, saw_wait);
        check(got_data && value == 16'h4433,
              "memory high-half read mapping failed");
        check(last_araddr == AXIL_MEM_BASE,
              "memory high-half AXI address mismatch");
        bus_read(1'b1, MEM_BASE + 24'h1, 2'b10,
                 value, got_data, saw_wait);
        check(got_data && value[15:8] == 8'h22,
              "memory odd upper-byte read failed");

        $display("TEST memory_write_mapping_and_backpressure");
        memory_write(MEM_BASE, 2'b11, 16'ha1b2, saw_wait);
        check(memory[0] == 32'h4433_a1b2 && saw_wait,
              "memory low-half write failed");
        check(last_awaddr == AXIL_MEM_BASE &&
              last_wdata == 32'h0000_a1b2 && last_wstrb == 4'b0011,
              "memory low-half AXI payload mismatch");
        allow_aw = 1'b0;
        allow_w = 1'b0;
        fork
            begin
                repeat (9) @(negedge a_clk);
                allow_w = 1'b1;
                repeat (5) @(negedge a_clk);
                allow_aw = 1'b1;
            end
            begin
                memory_write(MEM_BASE + 24'h2, 2'b11,
                             16'hc3d4, saw_wait);
            end
        join
        check(memory[0] == 32'hc3d4_a1b2,
              "memory high-half backpressured write failed");
        check(last_wdata == 32'hc3d4_0000 && last_wstrb == 4'b1100,
              "memory high-half AXI lane mismatch");
        memory_write(MEM_BASE + 24'h4, 2'b01, 16'h00ee, saw_wait);
        memory_write(MEM_BASE + 24'h5, 2'b10, 16'hff00, saw_wait);
        check(memory[1] == 32'h8877_ffee,
              "memory byte writes failed");

        $display("TEST io_memory_back_to_back_and_conflict");
        bus_read(1'b0, {8'h00, IO_BASE}, 2'b11,
                 value, got_data, saw_wait);
        check(got_data && value == 16'hcb98,
              "I/O path changed after memory integration");
        bus_read(1'b1, MEM_BASE + 24'h4, 2'b11,
                 value, got_data, saw_wait);
        check(got_data && value == 16'hffee,
              "memory path failed after I/O cycle");
        before_count = axi_ar_count;
        wait_idle();
        set_lane(MEM_BASE + 24'h8, 2'b11);
        cbus_ior_n = 1'b0;
        cbus_mrc_n = 1'b0;
        repeat (7) @(negedge c_clk);
        check(!cbus_data_oe && !cbus_iordy_oe,
              "I/O-memory conflict drove the bus");
        cbus_ior_n = 1'b1;
        cbus_mrc_n = 1'b1;
        wait_idle();
        check(axi_ar_count == before_count && invalid_sticky,
              "I/O-memory conflict reached AXI");
        before_count = axi_ar_count;
        bus_read(1'b1, MEM_BASE + 24'h100, 2'b11,
                 value, got_data, saw_wait);
        check(!got_data && axi_ar_count == before_count,
              "out-of-aperture memory read reached AXI");

        $display("TEST error_timeout_stale_and_recovery");
        force_error = 1'b1;
        bus_read(1'b1, MEM_BASE + 24'h8, 2'b11,
                 value, got_data, saw_wait);
        check(got_data && value == 16'he001 && backend_error_sticky,
              "memory AXI error mapping failed");
        force_error = 1'b0;
        hold_read_response = 1'b1;
        bus_read(1'b1, MEM_BASE + 24'hc, 2'b11,
                 value, got_data, saw_wait);
        check(got_data && value == 16'hffff && timeout_sticky,
              "memory CDC timeout fallback failed");
        before_count = stale_count;
        fork
            begin
                repeat (8) @(negedge c_clk);
                hold_read_response = 1'b0;
            end
            begin
                bus_read(1'b1, MEM_BASE, 2'b11,
                         value, got_data, saw_wait);
            end
        join
        check(stale_count > before_count,
              "late memory response was not quarantined");
        check(got_data && value == 16'ha1b2,
              "late memory response contaminated next cycle");

        platform_ready = 1'b0;
        #1;
        check(!cbus_data_oe && !cbus_iordy_oe,
              "platform gate did not disable memory outputs");
        rst_n = 1'b0;
        repeat (5) @(negedge c_clk);
        rst_n = 1'b1;
        repeat (4) @(negedge c_clk);
        platform_ready = 1'b1;
        repeat (6) @(negedge c_clk);
        latch_upper(7'h50);
        bus_read(1'b1, MEM_BASE, 2'b11,
                 value, got_data, saw_wait);
        check(got_data && value == 16'ha1b2 &&
              !timeout_sticky && !invalid_sticky &&
              !backend_error_sticky && !abort_sticky,
              "memory route did not recover after coherent reset");
        check(axi_aw_count == axi_w_count && axi_b_count == axi_aw_count,
              "memory AXI write channel counts differ");
        check(axi_r_count == axi_ar_count,
              "memory AXI read response count differs");

        if (failures == 0) begin
            $display("PASS: %0d checks", checks);
            $finish;
        end else begin
            $fatal(1, "FAIL: %0d of %0d checks failed", failures, checks);
        end
    end

endmodule

`default_nettype wire
