`timescale 1ns/1ps
`default_nettype none

module tb_axil_system_csr;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst_n;
    logic cbus_timeout_sticky_async, cbus_invalid_sticky_async;
    logic cbus_backend_error_sticky_async, cbus_abort_sticky_async;
    logic guard_faulted, guard_reject_sticky, guard_timeout_sticky;
    logic guard_downstream_error_sticky, guard_fault_valid;
    logic [2:0] guard_fault_code;
    logic guard_fault_write;
    logic [31:0] scratch_value;
    logic [31:0] s_axil_awaddr;
    logic [2:0] s_axil_awprot;
    logic s_axil_awvalid, s_axil_awready;
    logic [31:0] s_axil_wdata;
    logic [3:0] s_axil_wstrb;
    logic s_axil_wvalid, s_axil_wready;
    logic [1:0] s_axil_bresp;
    logic s_axil_bvalid, s_axil_bready;
    logic [31:0] s_axil_araddr;
    logic [2:0] s_axil_arprot;
    logic s_axil_arvalid, s_axil_arready;
    logic [31:0] s_axil_rdata;
    logic [1:0] s_axil_rresp;
    logic s_axil_rvalid, s_axil_rready;
    integer checks;

    axil_system_csr dut (.*);

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL check=%0d: %s", checks, message);
                $fatal(1);
            end
        end
    endtask

    task automatic axi_read(
        input logic [31:0] address,
        input integer response_stall,
        output logic [31:0] data,
        output logic [1:0] response
    );
        integer i;
        logic [31:0] held_data;
        logic [1:0] held_resp;
        begin
            @(negedge clk);
            s_axil_araddr = address;
            s_axil_arvalid = 1'b1;
            do @(posedge clk); while (!s_axil_arready);
            @(negedge clk);
            s_axil_arvalid = 1'b0;
            while (!s_axil_rvalid) @(posedge clk);
            held_data = s_axil_rdata;
            held_resp = s_axil_rresp;
            for (i = 0; i < response_stall; i = i + 1) begin
                @(posedge clk);
                check(s_axil_rvalid && s_axil_rdata === held_data && s_axil_rresp === held_resp,
                      "R payload stable under backpressure");
            end
            data = s_axil_rdata;
            response = s_axil_rresp;
            @(negedge clk);
            s_axil_rready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_axil_rready = 1'b0;
        end
    endtask

    task automatic send_aw(input logic [31:0] address);
        begin
            @(negedge clk);
            s_axil_awaddr = address;
            s_axil_awvalid = 1'b1;
            do @(posedge clk); while (!s_axil_awready);
            @(negedge clk);
            s_axil_awvalid = 1'b0;
        end
    endtask

    task automatic send_w(input logic [31:0] data, input logic [3:0] strobe);
        begin
            @(negedge clk);
            s_axil_wdata = data;
            s_axil_wstrb = strobe;
            s_axil_wvalid = 1'b1;
            do @(posedge clk); while (!s_axil_wready);
            @(negedge clk);
            s_axil_wvalid = 1'b0;
        end
    endtask

    task automatic axi_write(
        input logic [31:0] address,
        input logic [31:0] data,
        input logic [3:0] strobe,
        input integer channel_order,
        input integer response_stall,
        output logic [1:0] response
    );
        integer i;
        logic [1:0] held_resp;
        begin
            case (channel_order)
                1: begin send_aw(address); repeat (2) @(posedge clk); send_w(data, strobe); end
                2: begin send_w(data, strobe); repeat (2) @(posedge clk); send_aw(address); end
                default: fork send_aw(address); send_w(data, strobe); join
            endcase
            while (!s_axil_bvalid) @(posedge clk);
            held_resp = s_axil_bresp;
            for (i = 0; i < response_stall; i = i + 1) begin
                @(posedge clk);
                check(s_axil_bvalid && s_axil_bresp === held_resp,
                      "B response stable under backpressure");
            end
            response = s_axil_bresp;
            @(negedge clk);
            s_axil_bready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            s_axil_bready = 1'b0;
        end
    endtask

    logic [31:0] rd;
    logic [1:0] resp;

    initial begin
        checks = 0;
        rst_n = 1'b0;
        cbus_timeout_sticky_async = 1'b0; cbus_invalid_sticky_async = 1'b0;
        cbus_backend_error_sticky_async = 1'b0; cbus_abort_sticky_async = 1'b0;
        guard_faulted = 1'b0; guard_reject_sticky = 1'b0; guard_timeout_sticky = 1'b0;
        guard_downstream_error_sticky = 1'b0; guard_fault_valid = 1'b0;
        guard_fault_code = 3'b000; guard_fault_write = 1'b0;
        s_axil_awaddr = 0; s_axil_awprot = 0; s_axil_awvalid = 0;
        s_axil_wdata = 0; s_axil_wstrb = 0; s_axil_wvalid = 0; s_axil_bready = 0;
        s_axil_araddr = 0; s_axil_arprot = 0; s_axil_arvalid = 0; s_axil_rready = 0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        check(scratch_value === 32'h0000_0000, "scratch reset");

        axi_read(32'h1000_0000, 2, rd, resp);
        check(resp == 2'b00 && rd == 32'h4342_cb98, "product ID");
        axi_read(32'h1000_0004, 0, rd, resp);
        check(resp == 2'b00 && rd == 32'h00ff_0002, "version and capability");

        axi_write(32'h1000_0008, 32'h1122_3344, 4'b1111, 0, 2, resp);
        check(resp == 2'b00 && scratch_value == 32'h1122_3344, "simultaneous AW/W full scratch write");
        axi_write(32'h1000_0008, 32'haa00_cc00, 4'b1010, 1, 0, resp);
        check(resp == 2'b00 && scratch_value == 32'haa22_cc44, "AW-first byte strobes");
        axi_write(32'h1000_0008, 32'h00bb_00dd, 4'b0101, 2, 0, resp);
        check(resp == 2'b00 && scratch_value == 32'haabb_ccdd, "W-first byte strobes");
        axi_read(32'h1000_0008, 3, rd, resp);
        check(resp == 2'b00 && rd == 32'haabb_ccdd, "scratch readback");

        axi_write(32'h1000_0000, 32'hffff_ffff, 4'b1111, 0, 0, resp);
        check(resp == 2'b10 && scratch_value == 32'haabb_ccdd, "RO write SLVERR without side effect");
        axi_read(32'h1000_0010, 0, rd, resp);
        check(resp == 2'b11 && rd == 0, "out-of-range read DECERR");
        axi_read(32'h1000_0002, 0, rd, resp);
        check(resp == 2'b11 && rd == 0, "unaligned read DECERR");
        axi_write(32'h1000_0108, 32'h0, 4'b1111, 0, 0, resp);
        check(resp == 2'b11 && scratch_value == 32'haabb_ccdd, "out-of-range write DECERR");

        cbus_timeout_sticky_async = 1'b1;
        cbus_invalid_sticky_async = 1'b1;
        cbus_backend_error_sticky_async = 1'b1;
        cbus_abort_sticky_async = 1'b1;
        guard_faulted = 1'b1; guard_reject_sticky = 1'b1; guard_timeout_sticky = 1'b1;
        guard_downstream_error_sticky = 1'b1; guard_fault_valid = 1'b1;
        guard_fault_write = 1'b1; guard_fault_code = 3'b101;
        repeat (3) @(posedge clk);
        axi_read(32'h1000_000c, 1, rd, resp);
        check(resp == 2'b00 && rd[15:0] == 16'h17ff, "synchronized status summary");

        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        check(scratch_value === 32'h0000_0000 && !s_axil_bvalid && !s_axil_rvalid,
              "coherent reset clears state");

        $display("PASS tb_axil_system_csr checks=%0d", checks);
        $finish;
    end
endmodule

`default_nettype wire
