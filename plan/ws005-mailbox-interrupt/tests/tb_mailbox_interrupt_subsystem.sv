`timescale 1ns/1ps
`default_nettype none

module tb_mailbox_interrupt_subsystem;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n;
    logic [31:0] external_cpu_event_set, external_host_event_set;
    logic [31:0] cpu_pending, cpu_mask, cpu_active;
    logic cpu_irq_active;
    logic [31:0] host_pending, host_mask, host_active;
    logic host_irq_active;

    logic [31:0] intr_axil_awaddr;
    logic [2:0] intr_axil_awprot;
    logic intr_axil_awvalid, intr_axil_awready;
    logic [31:0] intr_axil_wdata;
    logic [3:0] intr_axil_wstrb;
    logic intr_axil_wvalid, intr_axil_wready;
    logic [1:0] intr_axil_bresp;
    logic intr_axil_bvalid, intr_axil_bready;
    logic [31:0] intr_axil_araddr;
    logic [2:0] intr_axil_arprot;
    logic intr_axil_arvalid, intr_axil_arready;
    logic [31:0] intr_axil_rdata;
    logic [1:0] intr_axil_rresp;
    logic intr_axil_rvalid, intr_axil_rready;

    logic [31:0] mbx_axil_awaddr;
    logic [2:0] mbx_axil_awprot;
    logic mbx_axil_awvalid, mbx_axil_awready;
    logic [31:0] mbx_axil_wdata;
    logic [3:0] mbx_axil_wstrb;
    logic mbx_axil_wvalid, mbx_axil_wready;
    logic [1:0] mbx_axil_bresp;
    logic mbx_axil_bvalid, mbx_axil_bready;
    logic [31:0] mbx_axil_araddr;
    logic [2:0] mbx_axil_arprot;
    logic mbx_axil_arvalid, mbx_axil_arready;
    logic [31:0] mbx_axil_rdata;
    logic [1:0] mbx_axil_rresp;
    logic mbx_axil_rvalid, mbx_axil_rready;

    integer checks;
    integer i;
    logic [31:0] rd;
    logic [1:0] resp;

    mailbox_interrupt_subsystem dut (.*);

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL check=%0d: %s", checks, message);
                $fatal(1);
            end
        end
    endtask

    task automatic intr_send_aw(input logic [31:0] address);
        begin
            @(negedge clk);
            intr_axil_awaddr = address;
            intr_axil_awvalid = 1'b1;
            do @(posedge clk); while (!intr_axil_awready);
            @(negedge clk);
            intr_axil_awvalid = 1'b0;
        end
    endtask

    task automatic intr_send_w(input logic [31:0] data, input logic [3:0] strobe);
        begin
            @(negedge clk);
            intr_axil_wdata = data;
            intr_axil_wstrb = strobe;
            intr_axil_wvalid = 1'b1;
            do @(posedge clk); while (!intr_axil_wready);
            @(negedge clk);
            intr_axil_wvalid = 1'b0;
        end
    endtask

    task automatic intr_write(
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [3:0] strobe,
        input integer order,
        input integer stall,
        output logic [1:0] response
    );
        integer n;
        logic [1:0] held;
        begin
            case (order)
                1: begin intr_send_aw(address); repeat (2) @(posedge clk); intr_send_w(data, strobe); end
                2: begin intr_send_w(data, strobe); repeat (2) @(posedge clk); intr_send_aw(address); end
                default: fork intr_send_aw(address); intr_send_w(data, strobe); join
            endcase
            while (!intr_axil_bvalid) @(posedge clk);
            held = intr_axil_bresp;
            for (n = 0; n < stall; n = n + 1) begin
                @(posedge clk);
                check(intr_axil_bvalid && intr_axil_bresp === held,
                      "interrupt B payload stable under backpressure");
            end
            response = intr_axil_bresp;
            @(negedge clk);
            intr_axil_bready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            intr_axil_bready = 1'b0;
        end
    endtask

    task automatic intr_read(
        input logic [31:0] address,
        input integer stall,
        output logic [31:0] data,
        output logic [1:0] response
    );
        integer n;
        logic [31:0] held_data;
        logic [1:0] held_resp;
        begin
            @(negedge clk);
            intr_axil_araddr = address;
            intr_axil_arvalid = 1'b1;
            do @(posedge clk); while (!intr_axil_arready);
            @(negedge clk);
            intr_axil_arvalid = 1'b0;
            while (!intr_axil_rvalid) @(posedge clk);
            held_data = intr_axil_rdata;
            held_resp = intr_axil_rresp;
            for (n = 0; n < stall; n = n + 1) begin
                @(posedge clk);
                check(intr_axil_rvalid && intr_axil_rdata === held_data && intr_axil_rresp === held_resp,
                      "interrupt R payload stable under backpressure");
            end
            data = intr_axil_rdata;
            response = intr_axil_rresp;
            @(negedge clk);
            intr_axil_rready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            intr_axil_rready = 1'b0;
        end
    endtask

    task automatic mbx_send_aw(input logic [31:0] address);
        begin
            @(negedge clk);
            mbx_axil_awaddr = address;
            mbx_axil_awvalid = 1'b1;
            do @(posedge clk); while (!mbx_axil_awready);
            @(negedge clk);
            mbx_axil_awvalid = 1'b0;
        end
    endtask

    task automatic mbx_send_w(input logic [31:0] data, input logic [3:0] strobe);
        begin
            @(negedge clk);
            mbx_axil_wdata = data;
            mbx_axil_wstrb = strobe;
            mbx_axil_wvalid = 1'b1;
            do @(posedge clk); while (!mbx_axil_wready);
            @(negedge clk);
            mbx_axil_wvalid = 1'b0;
        end
    endtask

    task automatic mbx_write(
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [3:0] strobe,
        input integer order,
        input integer stall,
        output logic [1:0] response
    );
        integer n;
        logic [1:0] held;
        begin
            case (order)
                1: begin mbx_send_aw(address); repeat (2) @(posedge clk); mbx_send_w(data, strobe); end
                2: begin mbx_send_w(data, strobe); repeat (2) @(posedge clk); mbx_send_aw(address); end
                default: fork mbx_send_aw(address); mbx_send_w(data, strobe); join
            endcase
            while (!mbx_axil_bvalid) @(posedge clk);
            held = mbx_axil_bresp;
            for (n = 0; n < stall; n = n + 1) begin
                @(posedge clk);
                check(mbx_axil_bvalid && mbx_axil_bresp === held,
                      "mailbox B payload stable under backpressure");
            end
            response = mbx_axil_bresp;
            @(negedge clk);
            mbx_axil_bready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mbx_axil_bready = 1'b0;
        end
    endtask

    task automatic mbx_read(
        input logic [31:0] address,
        input integer stall,
        output logic [31:0] data,
        output logic [1:0] response
    );
        integer n;
        logic [31:0] held_data;
        logic [1:0] held_resp;
        begin
            @(negedge clk);
            mbx_axil_araddr = address;
            mbx_axil_arvalid = 1'b1;
            do @(posedge clk); while (!mbx_axil_arready);
            @(negedge clk);
            mbx_axil_arvalid = 1'b0;
            while (!mbx_axil_rvalid) @(posedge clk);
            held_data = mbx_axil_rdata;
            held_resp = mbx_axil_rresp;
            for (n = 0; n < stall; n = n + 1) begin
                @(posedge clk);
                check(mbx_axil_rvalid && mbx_axil_rdata === held_data && mbx_axil_rresp === held_resp,
                      "mailbox R payload stable under backpressure");
            end
            data = mbx_axil_rdata;
            response = mbx_axil_rresp;
            @(negedge clk);
            mbx_axil_rready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            mbx_axil_rready = 1'b0;
        end
    endtask

    task automatic expect_intr_read(input logic [31:0] address, input logic [31:0] expected);
        begin
            intr_read(address, 0, rd, resp);
            check(resp == 2'b00 && rd == expected, "interrupt register read value");
        end
    endtask

    task automatic expect_mbx_read(input logic [31:0] address, input logic [31:0] expected);
        begin
            mbx_read(address, 0, rd, resp);
            check(resp == 2'b00 && rd == expected, "mailbox register read value");
        end
    endtask

    initial begin
        checks = 0;
        rst_n = 1'b0;
        external_cpu_event_set = 0;
        external_host_event_set = 0;
        intr_axil_awaddr = 0; intr_axil_awprot = 0; intr_axil_awvalid = 0;
        intr_axil_wdata = 0; intr_axil_wstrb = 0; intr_axil_wvalid = 0; intr_axil_bready = 0;
        intr_axil_araddr = 0; intr_axil_arprot = 0; intr_axil_arvalid = 0; intr_axil_rready = 0;
        mbx_axil_awaddr = 0; mbx_axil_awprot = 0; mbx_axil_awvalid = 0;
        mbx_axil_wdata = 0; mbx_axil_wstrb = 0; mbx_axil_wvalid = 0; mbx_axil_bready = 0;
        mbx_axil_araddr = 0; mbx_axil_arprot = 0; mbx_axil_arvalid = 0; mbx_axil_rready = 0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("TEST reset_register_map");
        expect_intr_read(32'h1000_2000, 32'h4952_0001);
        expect_intr_read(32'h1000_2004, 32'h0020_0001);
        expect_intr_read(32'h1000_2010, 32'h0000_0000);
        expect_intr_read(32'h1000_2014, 32'h0000_0000);
        expect_intr_read(32'h1000_2018, 32'h0000_0000);
        expect_intr_read(32'h1000_201c, 32'h0000_0000);
        expect_intr_read(32'h1000_2020, 32'h0000_0000);
        expect_intr_read(32'h1000_2024, 32'h0000_0000);
        expect_intr_read(32'h1000_2028, 32'h0000_0000);
        expect_intr_read(32'h1000_202c, 32'h0000_0000);

        expect_mbx_read(32'h1000_3000, 32'h4d42_0001);
        expect_mbx_read(32'h1000_3004, 32'h0820_0001);
        expect_mbx_read(32'h1000_3010, 32'h0000_0000);
        expect_mbx_read(32'h1000_3014, 32'h0000_0000);
        expect_mbx_read(32'h1000_3018, 32'h0000_0000);
        expect_mbx_read(32'h1000_3020, 32'h0000_0000);
        expect_mbx_read(32'h1000_3024, 32'h0000_0100);
        expect_mbx_read(32'h1000_3028, 32'h0000_0000);
        expect_mbx_read(32'h1000_302c, 32'h0000_0000);
        expect_mbx_read(32'h1000_3030, 32'h0000_0000);
        expect_mbx_read(32'h1000_303c, 32'h0000_0000);
        expect_mbx_read(32'h1000_3040, 32'h0000_0100);
        expect_mbx_read(32'h1000_3044, 32'h0000_0000);
        expect_mbx_read(32'h1000_3048, 32'h0000_0000);
        expect_mbx_read(32'h1000_3050, 32'h0000_0000);
        expect_mbx_read(32'h1000_3054, 32'h0000_0000);
        expect_mbx_read(32'h1000_3058, 32'h0000_0000);
        expect_mbx_read(32'h1000_305c, 32'h0000_0000);
        mbx_read(32'h1000_301c, 2, rd, resp);
        check(resp == 2'b00 && rd == 0, "empty H2C data read");
        mbx_read(32'h1000_3034, 0, rd, resp);
        check(resp == 2'b00 && rd == 0, "empty C2H low read");
        mbx_read(32'h1000_3038, 0, rd, resp);
        check(resp == 2'b00 && rd == 0, "empty C2H high read");
        repeat (3) @(posedge clk);
        mbx_read(32'h1000_3024, 0, rd, resp);
        check(rd[17] && rd[8], "empty H2C read records underflow");
        mbx_read(32'h1000_3040, 0, rd, resp);
        check(rd[17] && rd[8], "empty C2H reads record underflow");
        check(cpu_pending[3] && cpu_pending[5], "mailbox underflows route to CPU pending");

        mbx_write(32'h1000_302c, 32'h0002_0000, 4'b0100, 0, 0, resp);
        check(resp == 2'b00, "H2C underflow W1C write");
        mbx_write(32'h1000_3048, 32'h0002_0000, 4'b0100, 0, 0, resp);
        check(resp == 2'b00, "C2H underflow W1C write");
        intr_write(32'h1000_2018, 32'h0000_0028, 4'b0001, 0, 0, resp);
        check(resp == 2'b00, "CPU pending W1C write");
        repeat (3) @(posedge clk);

        $display("TEST access_errors_and_backpressure");
        intr_write(32'h1000_2000, 32'hffff_ffff, 4'b1111, 0, 2, resp);
        check(resp == 2'b10, "interrupt RO write SLVERR");
        intr_write(32'h1000_2010, 0, 4'b1111, 0, 0, resp);
        check(resp == 2'b10, "interrupt pending write SLVERR");
        intr_write(32'h1000_201c, 0, 4'b1111, 0, 0, resp);
        check(resp == 2'b10, "interrupt active write SLVERR");
        intr_read(32'h1000_2030, 0, rd, resp);
        check(resp == 2'b11 && rd == 0, "interrupt unimplemented read DECERR");
        intr_write(32'h1000_2015, 0, 4'b1111, 0, 0, resp);
        check(resp == 2'b11, "interrupt unaligned write DECERR");

        mbx_write(32'h1000_3000, 0, 4'b1111, 0, 0, resp);
        check(resp == 2'b10, "mailbox ID write SLVERR");
        mbx_write(32'h1000_3024, 0, 4'b1111, 0, 0, resp);
        check(resp == 2'b10, "mailbox status write SLVERR");
        mbx_write(32'h1000_3034, 0, 4'b1111, 0, 0, resp);
        check(resp == 2'b10, "mailbox C2H data write SLVERR");
        mbx_write(32'h1000_3030, 32'h1234_5678, 4'b0011, 0, 0, resp);
        check(resp == 2'b10, "PUSH32 partial strobe SLVERR");
        mbx_write(32'h1000_3018, 0, 4'b0001, 0, 0, resp);
        check(resp == 2'b10, "W1P missing command bit SLVERR");
        mbx_read(32'h1000_3060, 0, rd, resp);
        check(resp == 2'b11 && rd == 0, "mailbox unimplemented read DECERR");
        mbx_read(32'h1000_3002, 0, rd, resp);
        check(resp == 2'b11 && rd == 0, "mailbox unaligned read DECERR");

        $display("TEST interrupt_router");
        @(negedge clk);
        external_cpu_event_set = 32'h8000_00c0;
        external_host_event_set = 32'h0000_0006;
        @(posedge clk);
        @(negedge clk);
        external_cpu_event_set = 0;
        external_host_event_set = 0;
        repeat (2) @(posedge clk);
        check(cpu_pending == 32'h0000_0040, "CPU valid-source mask filters direct events");
        check(host_pending == 32'h0000_0002, "host valid-source mask filters direct events");
        check(!cpu_irq_active && !host_irq_active, "pending retained while masks are zero");
        intr_write(32'h1000_2014, 32'hffff_ffff, 4'b1111, 1, 2, resp);
        check(resp == 2'b00, "CPU mask AW-first write");
        intr_write(32'h1000_2024, 32'hffff_ffff, 4'b1111, 2, 0, resp);
        check(resp == 2'b00, "host mask W-first write");
        repeat (1) @(posedge clk);
        check(cpu_mask == 32'h00ff_037d && host_mask == 32'h0000_0002,
              "mask writes force reserved sources low");
        check(cpu_irq_active && host_irq_active && cpu_active[6] && host_active[1],
              "unmask exposes retained pending");

        fork
            intr_write(32'h1000_2018, 32'h0000_0040, 4'b0001, 0, 0, resp);
            begin
                @(negedge clk);
                external_cpu_event_set = 32'h0000_0040;
                @(posedge clk);
                @(negedge clk);
                external_cpu_event_set = 0;
            end
        join
        repeat (1) @(posedge clk);
        check(cpu_pending[6], "set wins over simultaneous W1C");
        intr_write(32'h1000_2018, 32'h0000_0040, 4'b0001, 0, 0, resp);
        intr_write(32'h1000_2028, 32'h0000_0002, 4'b0001, 0, 0, resp);
        repeat (3) @(posedge clk);
        check(!cpu_pending[6] && !host_pending[1], "W1C clears without set");

        $display("TEST H2C_fifo_and_errors");
        mbx_write(32'h1000_3010, 32'h0000_1234, 4'b0011, 1, 0, resp);
        check(resp == 2'b00, "H2C low staging write");
        mbx_write(32'h1000_3014, 32'h0000_abcd, 4'b0011, 2, 0, resp);
        check(resp == 2'b00, "H2C high staging write");
        mbx_write(32'h1000_3018, 32'h1, 4'b0001, 0, 1, resp);
        check(resp == 2'b00, "H2C push");
        mbx_write(32'h1000_3018, 32'h1, 4'b0001, 0, 0, resp);
        repeat (2) @(posedge clk);
        mbx_read(32'h1000_3024, 0, rd, resp);
        check(resp == 2'b00 && rd[3:0] == 2 && !rd[8] && !rd[9], "H2C occupancy two");
        mbx_read(32'h1000_301c, 0, rd, resp);
        check(rd == 32'habcd_1234, "H2C peek assembled staging word");
        mbx_write(32'h1000_3020, 32'h1, 4'b0001, 0, 0, resp);
        repeat (2) @(posedge clk);
        mbx_read(32'h1000_301c, 0, rd, resp);
        check(rd == 32'habcd_1234, "H2C duplicate staging push preserves ordering");
        mbx_write(32'h1000_3020, 32'h1, 4'b0001, 0, 0, resp);
        repeat (2) @(posedge clk);

        for (i = 0; i < 8; i = i + 1) begin
            mbx_write(32'h1000_3010, i, 4'b0011, 0, 0, resp);
            mbx_write(32'h1000_3014, 32'h0000_5500 + i, 4'b0011, 0, 0, resp);
            mbx_write(32'h1000_3018, 1, 4'b0001, 0, 0, resp);
        end
        repeat (2) @(posedge clk);
        mbx_write(32'h1000_3018, 1, 4'b0001, 0, 0, resp);
        repeat (3) @(posedge clk);
        mbx_read(32'h1000_3024, 0, rd, resp);
        check(rd[3:0] == 8 && rd[9] && rd[16], "H2C full push records overflow without corruption");
        check(cpu_pending[2], "H2C overflow routes to CPU pending");
        mbx_write(32'h1000_3028, 32'h0001_0000, 4'b0100, 0, 0, resp);
        repeat (2) @(posedge clk);
        mbx_read(32'h1000_3024, 0, rd, resp);
        check(!rd[16] && cpu_pending[2], "error sticky clears independently of router pending");
        for (i = 0; i < 8; i = i + 1)
            mbx_write(32'h1000_3020, 1, 4'b0001, 0, 0, resp);
        repeat (2) @(posedge clk);

        $display("TEST C2H_fifo");
        mbx_write(32'h1000_3030, 32'h1122_3344, 4'b1111, 0, 0, resp);
        mbx_write(32'h1000_3030, 32'haabb_ccdd, 4'b1111, 0, 0, resp);
        repeat (2) @(posedge clk);
        mbx_read(32'h1000_3034, 0, rd, resp);
        check(rd == 32'h0000_3344, "C2H low half peek");
        mbx_read(32'h1000_3038, 0, rd, resp);
        check(rd == 32'h0000_1122, "C2H high half same head");
        mbx_write(32'h1000_303c, 1, 4'b0001, 0, 0, resp);
        repeat (2) @(posedge clk);
        mbx_read(32'h1000_3034, 0, rd, resp);
        check(rd == 32'h0000_ccdd, "C2H explicit pop advances head");
        mbx_write(32'h1000_303c, 1, 4'b0001, 0, 0, resp);
        repeat (2) @(posedge clk);
        mbx_write(32'h1000_303c, 1, 4'b0001, 0, 0, resp);
        repeat (3) @(posedge clk);
        mbx_read(32'h1000_3040, 0, rd, resp);
        check(rd[8] && rd[17] && cpu_pending[5], "C2H empty pop records sticky and event");

        $display("TEST doorbell_coalescing");
        mbx_write(32'h1000_3050, 1, 4'b0001, 0, 0, resp);
        mbx_write(32'h1000_3054, 2, 4'b0001, 0, 0, resp);
        repeat (3) @(posedge clk);
        check(cpu_pending[0] && host_pending[1], "doorbells set destination pending");
        mbx_read(32'h1000_3058, 0, rd, resp);
        check(rd[1:0] == 2'b11 && rd[17:16] == 0, "first doorbells not coalesced");
        mbx_write(32'h1000_3050, 1, 4'b0001, 0, 0, resp);
        mbx_write(32'h1000_3054, 2, 4'b0001, 0, 0, resp);
        repeat (3) @(posedge clk);
        mbx_read(32'h1000_3058, 3, rd, resp);
        check(rd[1:0] == 2'b11 && rd[17:16] == 2'b11, "repeated doorbells coalesce sticky");
        intr_write(32'h1000_2018, 1, 4'b0001, 0, 0, resp);
        intr_write(32'h1000_2028, 2, 4'b0001, 0, 0, resp);
        repeat (3) @(posedge clk);
        mbx_read(32'h1000_3058, 0, rd, resp);
        check(rd[1:0] == 0 && rd[17:16] == 2'b11, "pending ack does not clear coalesced sticky");
        mbx_write(32'h1000_305c, 32'h0003_0000, 4'b0100, 0, 0, resp);
        repeat (2) @(posedge clk);
        mbx_read(32'h1000_3058, 0, rd, resp);
        check(rd == 0, "coalesced W1C clears independently");

        $display("TEST reset_and_recovery");
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        check(cpu_pending == 0 && host_pending == 0 && cpu_mask == 0 && host_mask == 0,
              "reset clears router state");
        check(!cpu_irq_active && !host_irq_active && !intr_axil_bvalid && !intr_axil_rvalid,
              "reset clears interrupt responses and IRQs");
        check(!mbx_axil_bvalid && !mbx_axil_rvalid, "reset clears mailbox responses");
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        mbx_read(32'h1000_3024, 0, rd, resp);
        check(resp == 2'b00 && rd == 32'h0000_0100, "H2C reset state recovered");
        mbx_read(32'h1000_3040, 0, rd, resp);
        check(resp == 2'b00 && rd == 32'h0000_0100, "C2H reset state recovered");

        $display("PASS tb_mailbox_interrupt_subsystem checks=%0d", checks);
        $finish;
    end
endmodule

`default_nettype wire
