`timescale 1ns/1ps
`default_nettype none

module axil_test_target #(
    parameter logic [7:0] TARGET_ID = 8'h00
) (
    input logic clk, input logic rst_n,
    input logic [31:0] awaddr, input logic awvalid, output logic awready,
    input logic [31:0] wdata, input logic [3:0] wstrb,
    input logic wvalid, output logic wready,
    output logic [1:0] bresp, output logic bvalid, input logic bready,
    input logic [31:0] araddr, input logic arvalid, output logic arready,
    output logic [31:0] rdata, output logic [1:0] rresp,
    output logic rvalid, input logic rready,
    output integer write_count, output integer read_count
);
    logic aw_seen, w_seen;
    always_comb begin
        awready = !bvalid;
        wready = !bvalid;
        arready = !rvalid;
        bresp = 2'b00;
        rresp = 2'b00;
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_seen <= 1'b0; w_seen <= 1'b0;
            bvalid <= 1'b0; rvalid <= 1'b0; rdata <= 32'h0;
            write_count <= 0; read_count <= 0;
        end else begin
            if (bvalid && bready) bvalid <= 1'b0;
            if (rvalid && rready) rvalid <= 1'b0;
            if (awvalid && awready) aw_seen <= 1'b1;
            if (wvalid && wready) w_seen <= 1'b1;
            if (!bvalid && (aw_seen || (awvalid && awready)) &&
                (w_seen || (wvalid && wready))) begin
                aw_seen <= 1'b0; w_seen <= 1'b0;
                bvalid <= 1'b1;
                write_count <= write_count + 1;
            end
            if (arvalid && arready) begin
                rvalid <= 1'b1;
                rdata <= {TARGET_ID, araddr[23:0]};
                read_count <= read_count + 1;
            end
        end
    end
    wire unused_payload = ^{awaddr, wdata, wstrb};
endmodule

module tb_axil_control_fabric_1x3;
    logic clk = 1'b0, rst_n = 1'b0;
    always #5 clk = ~clk;
    logic [31:0] s_awaddr, s_wdata, s_araddr, s_rdata;
    logic [2:0] s_awprot, s_arprot;
    logic [3:0] s_wstrb;
    logic s_awvalid, s_awready, s_wvalid, s_wready;
    logic [1:0] s_bresp, s_rresp;
    logic s_bvalid, s_bready, s_arvalid, s_arready, s_rvalid, s_rready;

`define TARGET_SIGNALS(N) \
    logic [31:0] m``N``_awaddr, m``N``_wdata, m``N``_araddr, m``N``_rdata; \
    logic [2:0] m``N``_awprot, m``N``_arprot; \
    logic [3:0] m``N``_wstrb; \
    logic m``N``_awvalid, m``N``_awready, m``N``_wvalid, m``N``_wready; \
    logic [1:0] m``N``_bresp, m``N``_rresp; \
    logic m``N``_bvalid, m``N``_bready, m``N``_arvalid, m``N``_arready; \
    logic m``N``_rvalid, m``N``_rready; integer writes``N``, reads``N``;
    `TARGET_SIGNALS(0)
    `TARGET_SIGNALS(1)
    `TARGET_SIGNALS(2)
`undef TARGET_SIGNALS
    integer checks;

    axil_control_fabric_1x3 dut (
        .clk(clk), .rst_n(rst_n),
        .s_axil_awaddr(s_awaddr), .s_axil_awprot(s_awprot),
        .s_axil_awvalid(s_awvalid), .s_axil_awready(s_awready),
        .s_axil_wdata(s_wdata), .s_axil_wstrb(s_wstrb),
        .s_axil_wvalid(s_wvalid), .s_axil_wready(s_wready),
        .s_axil_bresp(s_bresp), .s_axil_bvalid(s_bvalid), .s_axil_bready(s_bready),
        .s_axil_araddr(s_araddr), .s_axil_arprot(s_arprot),
        .s_axil_arvalid(s_arvalid), .s_axil_arready(s_arready),
        .s_axil_rdata(s_rdata), .s_axil_rresp(s_rresp),
        .s_axil_rvalid(s_rvalid), .s_axil_rready(s_rready),
        .m0_axil_awaddr(m0_awaddr), .m0_axil_awprot(m0_awprot),
        .m0_axil_awvalid(m0_awvalid), .m0_axil_awready(m0_awready),
        .m0_axil_wdata(m0_wdata), .m0_axil_wstrb(m0_wstrb),
        .m0_axil_wvalid(m0_wvalid), .m0_axil_wready(m0_wready),
        .m0_axil_bresp(m0_bresp), .m0_axil_bvalid(m0_bvalid), .m0_axil_bready(m0_bready),
        .m0_axil_araddr(m0_araddr), .m0_axil_arprot(m0_arprot),
        .m0_axil_arvalid(m0_arvalid), .m0_axil_arready(m0_arready),
        .m0_axil_rdata(m0_rdata), .m0_axil_rresp(m0_rresp),
        .m0_axil_rvalid(m0_rvalid), .m0_axil_rready(m0_rready),
        .m1_axil_awaddr(m1_awaddr), .m1_axil_awprot(m1_awprot),
        .m1_axil_awvalid(m1_awvalid), .m1_axil_awready(m1_awready),
        .m1_axil_wdata(m1_wdata), .m1_axil_wstrb(m1_wstrb),
        .m1_axil_wvalid(m1_wvalid), .m1_axil_wready(m1_wready),
        .m1_axil_bresp(m1_bresp), .m1_axil_bvalid(m1_bvalid), .m1_axil_bready(m1_bready),
        .m1_axil_araddr(m1_araddr), .m1_axil_arprot(m1_arprot),
        .m1_axil_arvalid(m1_arvalid), .m1_axil_arready(m1_arready),
        .m1_axil_rdata(m1_rdata), .m1_axil_rresp(m1_rresp),
        .m1_axil_rvalid(m1_rvalid), .m1_axil_rready(m1_rready),
        .m2_axil_awaddr(m2_awaddr), .m2_axil_awprot(m2_awprot),
        .m2_axil_awvalid(m2_awvalid), .m2_axil_awready(m2_awready),
        .m2_axil_wdata(m2_wdata), .m2_axil_wstrb(m2_wstrb),
        .m2_axil_wvalid(m2_wvalid), .m2_axil_wready(m2_wready),
        .m2_axil_bresp(m2_bresp), .m2_axil_bvalid(m2_bvalid), .m2_axil_bready(m2_bready),
        .m2_axil_araddr(m2_araddr), .m2_axil_arprot(m2_arprot),
        .m2_axil_arvalid(m2_arvalid), .m2_axil_arready(m2_arready),
        .m2_axil_rdata(m2_rdata), .m2_axil_rresp(m2_rresp),
        .m2_axil_rvalid(m2_rvalid), .m2_axil_rready(m2_rready)
    );

`define TARGET_INSTANCE(N, ID) \
    axil_test_target #(.TARGET_ID(ID)) target``N`` ( \
        .clk(clk), .rst_n(rst_n), .awaddr(m``N``_awaddr), \
        .awvalid(m``N``_awvalid), .awready(m``N``_awready), \
        .wdata(m``N``_wdata), .wstrb(m``N``_wstrb), \
        .wvalid(m``N``_wvalid), .wready(m``N``_wready), \
        .bresp(m``N``_bresp), .bvalid(m``N``_bvalid), .bready(m``N``_bready), \
        .araddr(m``N``_araddr), .arvalid(m``N``_arvalid), .arready(m``N``_arready), \
        .rdata(m``N``_rdata), .rresp(m``N``_rresp), .rvalid(m``N``_rvalid), \
        .rready(m``N``_rready), .write_count(writes``N``), .read_count(reads``N``));
    `TARGET_INSTANCE(0, 8'h10)
    `TARGET_INSTANCE(1, 8'h20)
    `TARGET_INSTANCE(2, 8'h30)
`undef TARGET_INSTANCE

    task automatic check(input logic condition, input string message);
        begin checks = checks + 1; if (!condition) begin
            $display("FAIL check=%0d %s", checks, message); $fatal(1); end end
    endtask

    task automatic send_aw(input logic [31:0] address);
        begin
            s_awaddr = address; s_awvalid = 1'b1;
            do @(posedge clk); while (!s_awready);
            #1 s_awvalid = 1'b0;
        end
    endtask
    task automatic send_w(input logic [31:0] data);
        begin
            s_wdata = data; s_wstrb = 4'hf; s_wvalid = 1'b1;
            do @(posedge clk); while (!s_wready);
            #1 s_wvalid = 1'b0;
        end
    endtask
    task automatic finish_write(input logic [1:0] expected_resp);
        integer timeout;
        begin
            timeout = 0; while (!s_bvalid && timeout < 30) begin
                @(posedge clk); timeout = timeout + 1; end
            check(s_bvalid && s_bresp == expected_resp, "write response");
            repeat (2) @(posedge clk);
            check(s_bvalid && s_bresp == expected_resp, "B payload holds under backpressure");
            s_bready = 1'b1; @(posedge clk); #1 s_bready = 1'b0;
        end
    endtask
    task automatic write_ordered(input logic [31:0] address, input integer mode);
        begin
            if (mode == 0) begin send_aw(address); repeat (2) @(posedge clk); send_w(address); end
            else if (mode == 1) begin send_w(address); repeat (2) @(posedge clk); send_aw(address); end
            else fork send_aw(address); send_w(address); join
            finish_write(2'b00);
        end
    endtask
    task automatic read_address(input logic [31:0] address, input logic [7:0] id);
        integer timeout; logic [31:0] held;
        begin
            s_araddr = address; s_arvalid = 1'b1;
            do @(posedge clk); while (!s_arready);
            #1 s_arvalid = 1'b0;
            timeout = 0; while (!s_rvalid && timeout < 30) begin
                @(posedge clk); timeout = timeout + 1; end
            check(s_rvalid && s_rresp == 2'b00 && s_rdata[31:24] == id, "read target response");
            held = s_rdata; repeat (2) @(posedge clk);
            check(s_rvalid && s_rdata == held, "R payload holds under backpressure");
            s_rready = 1'b1; @(posedge clk); #1 s_rready = 1'b0;
        end
    endtask

    initial begin
        checks = 0; s_awaddr = 0; s_awprot = 0; s_awvalid = 0;
        s_wdata = 0; s_wstrb = 0; s_wvalid = 0; s_bready = 0;
        s_araddr = 0; s_arprot = 0; s_arvalid = 0; s_rready = 0;
        repeat (3) @(posedge clk); rst_n = 1'b1; repeat (2) @(posedge clk);

        write_ordered(32'h1000_0008, 0);
        write_ordered(32'h1000_2024, 1);
        write_ordered(32'h1000_3010, 2);
        check(writes0 == 1 && writes1 == 1 && writes2 == 1,
              "AW-first/W-first/simultaneous route to distinct targets");

        read_address(32'h1000_0000, 8'h10);
        read_address(32'h1000_2020, 8'h20);
        read_address(32'h1000_3024, 8'h30);
        check(reads0 == 1 && reads1 == 1 && reads2 == 1,
              "reads route to three targets");

        fork send_aw(32'h1000_1000); send_w(32'hdead_beef); join
        finish_write(2'b11);
        check(writes0 == 1 && writes1 == 1 && writes2 == 1,
              "0x1000_1xxx local DECERR does not drive targets");

        s_araddr = 32'h8000_0000; s_arvalid = 1'b1;
        do @(posedge clk); while (!s_arready);
        #1 s_arvalid = 1'b0;
        while (!s_rvalid) @(posedge clk);
        check(s_rresp == 2'b11 && reads0 == 1 && reads1 == 1 && reads2 == 1,
              "out-of-range read is local DECERR");
        s_rready = 1'b1; @(posedge clk); #1 s_rready = 1'b0;

        send_aw(32'h1000_0008);
        check(s_wready, "split write address is buffered while waiting for W");
        rst_n = 1'b0; @(posedge clk);
        check(!s_bvalid && !s_rvalid && !m0_awvalid && !m1_awvalid && !m2_awvalid,
              "reset clears held split transaction and responses");
        $display("PASS tb_axil_control_fabric_1x3 checks=%0d", checks);
        $finish;
    end

    wire unused_prot = ^{m0_awprot, m0_arprot, m1_awprot, m1_arprot,
                         m2_awprot, m2_arprot};
endmodule

`default_nettype wire
