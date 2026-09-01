`timescale 1ns/1ps
`default_nettype none

module tb_axil_guard_timeout;

    localparam logic [31:0] ALLOW_BASE = 32'h1000_0000;
    localparam integer MAX_CYCLES = 80;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic status_clear = 1'b0;
    logic fault_clear = 1'b0;

    logic faulted;
    logic fault_reset_req;
    logic guard_sticky;
    logic timeout_sticky;
    logic downstream_error_sticky;
    logic fault_valid;
    logic [2:0] fault_code;
    logic fault_write;
    logic [31:0] fault_addr;

    logic [31:0] s_awaddr = 32'h0000_0000;
    logic [2:0] s_awprot = 3'b000;
    logic s_awvalid = 1'b0;
    logic s_awready;
    logic [31:0] s_wdata = 32'h0000_0000;
    logic [3:0] s_wstrb = 4'b0000;
    logic s_wvalid = 1'b0;
    logic s_wready;
    logic [1:0] s_bresp;
    logic s_bvalid;
    logic s_bready = 1'b0;
    logic [31:0] s_araddr = 32'h0000_0000;
    logic [2:0] s_arprot = 3'b000;
    logic s_arvalid = 1'b0;
    logic s_arready;
    logic [31:0] s_rdata;
    logic [1:0] s_rresp;
    logic s_rvalid;
    logic s_rready = 1'b0;

    logic [31:0] m_awaddr;
    logic [2:0] m_awprot;
    logic m_awvalid;
    logic m_awready;
    logic [31:0] m_wdata;
    logic [3:0] m_wstrb;
    logic m_wvalid;
    logic m_wready;
    logic [1:0] m_bresp;
    logic m_bvalid;
    logic m_bready;
    logic [31:0] m_araddr;
    logic [2:0] m_arprot;
    logic m_arvalid;
    logic m_arready;
    logic [31:0] m_rdata;
    logic [1:0] m_rresp;
    logic m_rvalid;
    logic m_rready;

    logic model_rst_n = 1'b0;
    logic allow_aw = 1'b1;
    logic allow_w = 1'b1;
    logic allow_ar = 1'b1;
    logic auto_b = 1'b1;
    logic auto_r = 1'b1;
    logic [1:0] configured_bresp = 2'b00;
    logic [1:0] configured_rresp = 2'b00;
    logic [31:0] configured_rdata = 32'h55aa_1234;
    logic manual_rvalid = 1'b0;
    logic [1:0] manual_rresp = 2'b00;
    logic [31:0] manual_rdata = 32'h0000_0000;

    logic d_aw_seen;
    logic d_w_seen;
    logic d_bvalid;
    logic [1:0] d_bresp;
    logic d_rvalid;
    logic [1:0] d_rresp;
    logic [31:0] d_rdata;
    integer downstream_aw_count = 0;
    integer downstream_w_count = 0;
    integer downstream_b_count = 0;
    integer downstream_ar_count = 0;
    integer downstream_r_count = 0;
    integer upstream_aw_count = 0;
    integer upstream_w_count = 0;
    integer upstream_ar_count = 0;
    integer checks = 0;
    integer failures = 0;

    assign m_awready = model_rst_n && allow_aw && !d_aw_seen;
    assign m_wready = model_rst_n && allow_w && !d_w_seen;
    assign m_arready = model_rst_n && allow_ar && !d_rvalid;
    assign m_bvalid = d_bvalid;
    assign m_bresp = d_bresp;
    assign m_rvalid = d_rvalid || manual_rvalid;
    assign m_rresp = manual_rvalid ? manual_rresp : d_rresp;
    assign m_rdata = manual_rvalid ? manual_rdata : d_rdata;

    always #5 clk = ~clk;

    axil_guard_timeout #(
        .ALLOW_BASE_ADDR(ALLOW_BASE),
        .ALLOW_ADDR_MASK(32'hffff_f000),
        .TIMEOUT_CYCLES(6),
        .ERROR_RDATA(32'hffff_ffff)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .status_clear(status_clear),
        .fault_clear(fault_clear),
        .faulted(faulted),
        .fault_reset_req(fault_reset_req),
        .guard_sticky(guard_sticky),
        .timeout_sticky(timeout_sticky),
        .downstream_error_sticky(downstream_error_sticky),
        .fault_valid(fault_valid),
        .fault_code(fault_code),
        .fault_write(fault_write),
        .fault_addr(fault_addr),
        .s_axil_awaddr(s_awaddr),
        .s_axil_awprot(s_awprot),
        .s_axil_awvalid(s_awvalid),
        .s_axil_awready(s_awready),
        .s_axil_wdata(s_wdata),
        .s_axil_wstrb(s_wstrb),
        .s_axil_wvalid(s_wvalid),
        .s_axil_wready(s_wready),
        .s_axil_bresp(s_bresp),
        .s_axil_bvalid(s_bvalid),
        .s_axil_bready(s_bready),
        .s_axil_araddr(s_araddr),
        .s_axil_arprot(s_arprot),
        .s_axil_arvalid(s_arvalid),
        .s_axil_arready(s_arready),
        .s_axil_rdata(s_rdata),
        .s_axil_rresp(s_rresp),
        .s_axil_rvalid(s_rvalid),
        .s_axil_rready(s_rready),
        .m_axil_awaddr(m_awaddr),
        .m_axil_awprot(m_awprot),
        .m_axil_awvalid(m_awvalid),
        .m_axil_awready(m_awready),
        .m_axil_wdata(m_wdata),
        .m_axil_wstrb(m_wstrb),
        .m_axil_wvalid(m_wvalid),
        .m_axil_wready(m_wready),
        .m_axil_bresp(m_bresp),
        .m_axil_bvalid(m_bvalid),
        .m_axil_bready(m_bready),
        .m_axil_araddr(m_araddr),
        .m_axil_arprot(m_arprot),
        .m_axil_arvalid(m_arvalid),
        .m_axil_arready(m_arready),
        .m_axil_rdata(m_rdata),
        .m_axil_rresp(m_rresp),
        .m_axil_rvalid(m_rvalid),
        .m_axil_rready(m_rready)
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

    task automatic pulse_status_clear;
        begin
            @(negedge clk);
            status_clear = 1'b1;
            @(negedge clk);
            status_clear = 1'b0;
        end
    endtask

    task automatic reset_downstream_and_clear_fault;
        begin
            allow_aw = 1'b0;
            allow_w = 1'b0;
            allow_ar = 1'b0;
            model_rst_n = 1'b0;
            repeat (2) @(negedge clk);
            model_rst_n = 1'b1;
            repeat (2) @(negedge clk);
            fault_clear = 1'b1;
            @(negedge clk);
            fault_clear = 1'b0;
            repeat (2) @(negedge clk);
            check(!faulted && !fault_reset_req,
                  "fault clear did not release quarantine");
            check(!m_awvalid && !m_wvalid && !m_arvalid,
                  "fault clear did not remove quarantined VALID");
            allow_aw = 1'b1;
            allow_w = 1'b1;
            allow_ar = 1'b1;
        end
    endtask

    task automatic drive_aw(input logic [31:0] addr);
        integer start_count;
        begin
            start_count = upstream_aw_count;
            @(negedge clk);
            s_awaddr = addr;
            s_awvalid = 1'b1;
            while (upstream_aw_count == start_count)
                @(negedge clk);
            s_awvalid = 1'b0;
        end
    endtask

    task automatic drive_w(
        input logic [31:0] data,
        input logic [3:0] strb
    );
        integer start_count;
        begin
            start_count = upstream_w_count;
            @(negedge clk);
            s_wdata = data;
            s_wstrb = strb;
            s_wvalid = 1'b1;
            while (upstream_w_count == start_count)
                @(negedge clk);
            s_wvalid = 1'b0;
        end
    endtask

    task automatic collect_b(output logic [1:0] resp);
        integer count;
        begin
            count = 0;
            while (!s_bvalid && count < MAX_CYCLES) begin
                @(negedge clk);
                count = count + 1;
            end
            check(s_bvalid, "upstream write response timed out");
            resp = s_bresp;
            s_bready = 1'b1;
            @(negedge clk);
            s_bready = 1'b0;
        end
    endtask

    task automatic axil_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0] strb,
        output logic [1:0] resp
    );
        begin
            fork
                drive_aw(addr);
                drive_w(data, strb);
            join
            collect_b(resp);
        end
    endtask

    task automatic axil_write_aw_first(
        input logic [31:0] addr,
        input logic [31:0] data,
        output logic [1:0] resp
    );
        begin
            drive_aw(addr);
            repeat (3) @(negedge clk);
            drive_w(data, 4'b1111);
            collect_b(resp);
        end
    endtask

    task automatic axil_read(
        input logic [31:0] addr,
        output logic [31:0] data,
        output logic [1:0] resp
    );
        integer start_count;
        integer count;
        begin
            start_count = upstream_ar_count;
            @(negedge clk);
            s_araddr = addr;
            s_arvalid = 1'b1;
            while (upstream_ar_count == start_count)
                @(negedge clk);
            s_arvalid = 1'b0;

            count = 0;
            while (!s_rvalid && count < MAX_CYCLES) begin
                @(negedge clk);
                count = count + 1;
            end
            check(s_rvalid, "upstream read response timed out");
            data = s_rdata;
            resp = s_rresp;
            s_rready = 1'b1;
            @(negedge clk);
            s_rready = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (s_awvalid && s_awready)
            upstream_aw_count = upstream_aw_count + 1;
        if (s_wvalid && s_wready)
            upstream_w_count = upstream_w_count + 1;
        if (s_arvalid && s_arready)
            upstream_ar_count = upstream_ar_count + 1;
    end

    always_ff @(posedge clk or negedge model_rst_n) begin
        if (!model_rst_n) begin
            d_aw_seen <= 1'b0;
            d_w_seen <= 1'b0;
            d_bvalid <= 1'b0;
            d_bresp <= 2'b00;
            d_rvalid <= 1'b0;
            d_rresp <= 2'b00;
            d_rdata <= 32'h0000_0000;
            downstream_aw_count <= 0;
            downstream_w_count <= 0;
            downstream_b_count <= 0;
            downstream_ar_count <= 0;
            downstream_r_count <= 0;
        end else begin
            if (m_awvalid && m_awready) begin
                d_aw_seen <= 1'b1;
                downstream_aw_count <= downstream_aw_count + 1;
            end
            if (m_wvalid && m_wready) begin
                d_w_seen <= 1'b1;
                downstream_w_count <= downstream_w_count + 1;
            end
            if (d_aw_seen && d_w_seen && auto_b && !d_bvalid) begin
                d_bresp <= configured_bresp;
                d_bvalid <= 1'b1;
            end
            if (d_bvalid && m_bready) begin
                d_bvalid <= 1'b0;
                d_aw_seen <= 1'b0;
                d_w_seen <= 1'b0;
                downstream_b_count <= downstream_b_count + 1;
            end

            if (m_arvalid && m_arready) begin
                downstream_ar_count <= downstream_ar_count + 1;
                if (auto_r) begin
                    d_rdata <= configured_rdata;
                    d_rresp <= configured_rresp;
                    d_rvalid <= 1'b1;
                end
            end
            if (d_rvalid && m_rready) begin
                d_rvalid <= 1'b0;
                downstream_r_count <= downstream_r_count + 1;
            end
            if (manual_rvalid && m_rready)
                downstream_r_count <= downstream_r_count + 1;
        end
    end

    initial begin
        logic [31:0] read_data;
        logic [1:0] response;
        integer before_aw;
        integer before_w;
        integer before_ar;
        integer before_r;
        logic [31:0] held_addr;
        logic [31:0] held_data;

        $dumpfile("tb_axil_guard_timeout.vcd");
        $dumpvars(0, tb_axil_guard_timeout);

        repeat (4) @(negedge clk);
        rst_n = 1'b1;
        model_rst_n = 1'b1;
        repeat (4) @(negedge clk);

        $display("TEST allowed_and_split_channels");
        axil_write_aw_first(
            ALLOW_BASE + 32'h0000_0008,
            32'h1122_3344, response);
        check(response == 2'b00, "allowed split write failed");
        check(downstream_aw_count == 1 && downstream_w_count == 1,
              "allowed write was not forwarded exactly once");
        check(m_awprot == 3'b000, "AWPROT changed through guard");

        configured_rdata = 32'h89ab_cdef;
        axil_read(ALLOW_BASE + 32'h0000_000c, read_data, response);
        check(response == 2'b00 && read_data == 32'h89ab_cdef,
              "allowed read failed");
        check(m_arprot == 3'b000, "ARPROT changed through guard");

        $display("TEST region_reject_and_first_fault");
        before_ar = downstream_ar_count;
        axil_read(32'h8000_0000, read_data, response);
        check(response == 2'b11 && read_data == 32'hffff_ffff,
              "host aperture read was not DECERR");
        check(downstream_ar_count == before_ar,
              "forbidden read reached downstream");
        check(guard_sticky && fault_valid && fault_code == 3'd1 &&
              !fault_write && fault_addr == 32'h8000_0000,
              "guard read fault record mismatch");
        check(!faulted, "region reject incorrectly quarantined guard");

        before_aw = downstream_aw_count;
        before_w = downstream_w_count;
        axil_write(32'h8100_0000, 32'hdead_beef, 4'b1111, response);
        check(response == 2'b11, "host aperture write was not DECERR");
        check(downstream_aw_count == before_aw &&
              downstream_w_count == before_w,
              "forbidden write reached downstream");
        check(fault_addr == 32'h8000_0000 && !fault_write,
              "first-fault record was overwritten");

        pulse_status_clear();
        check(!guard_sticky && !fault_valid,
              "status clear did not clear guard record");

        $display("TEST downstream_error_record");
        configured_rresp = 2'b10;
        axil_read(ALLOW_BASE, read_data, response);
        check(response == 2'b10, "downstream SLVERR was not forwarded");
        check(downstream_error_sticky && fault_valid &&
              fault_code == 3'd4 && !fault_write &&
              fault_addr == ALLOW_BASE,
              "downstream error record mismatch");
        check(!faulted, "completed downstream error quarantined guard");
        configured_rresp = 2'b00;
        pulse_status_clear();

        $display("TEST read_issue_timeout_and_valid_hold");
        allow_ar = 1'b0;
        before_ar = downstream_ar_count;
        axil_read(ALLOW_BASE + 32'h0000_0004, read_data, response);
        check(response == 2'b10 && read_data == 32'hffff_ffff,
              "read issue timeout response mismatch");
        check(faulted && fault_reset_req && timeout_sticky &&
              fault_code == 3'd2 && !fault_write,
              "read issue timeout did not quarantine");
        check(m_arvalid && m_araddr == ALLOW_BASE + 32'h0000_0004,
              "timed-out ARVALID/payload was not retained");
        held_addr = m_araddr;
        repeat (4) begin
            @(negedge clk);
            check(m_arvalid && m_araddr == held_addr,
                  "quarantined AR payload changed");
        end
        axil_read(ALLOW_BASE + 32'h0000_0008, read_data, response);
        check(response == 2'b11,
              "faulted guard did not locally reject new read");
        check(downstream_ar_count == before_ar,
              "faulted request reached downstream");
        check(m_arvalid && m_araddr == held_addr,
              "faulted read overwrote quarantined AR payload");
        reset_downstream_and_clear_fault();
        pulse_status_clear();

        configured_rdata = 32'h0102_0304;
        axil_read(ALLOW_BASE, read_data, response);
        check(response == 2'b00 && read_data == 32'h0102_0304,
              "read did not recover after subordinate reset");

        $display("TEST partial_write_timeout_and_payload_hold");
        allow_aw = 1'b1;
        allow_w = 1'b0;
        before_aw = downstream_aw_count;
        before_w = downstream_w_count;
        axil_write(
            ALLOW_BASE + 32'h0000_0008,
            32'ha5a5_5a5a, 4'b0011, response);
        check(response == 2'b10, "partial write timeout response mismatch");
        check(faulted && fault_code == 3'd2 && fault_write,
              "partial write timeout record mismatch");
        check(downstream_aw_count == before_aw + 1 &&
              downstream_w_count == before_w,
              "partial write handshake classification mismatch");
        check(!m_awvalid && m_wvalid,
              "partial write pending VALID mismatch");
        held_data = m_wdata;
        repeat (4) begin
            @(negedge clk);
            check(m_wvalid && m_wdata == held_data &&
                  m_wstrb == 4'b0011,
                  "quarantined W payload changed");
        end
        axil_write(
            ALLOW_BASE, 32'h5555_aaaa, 4'b1111, response);
        check(response == 2'b11,
              "faulted guard did not locally reject new write");
        check(downstream_aw_count == before_aw + 1 &&
              downstream_w_count == before_w,
              "faulted write reached downstream");
        check(m_wvalid && m_wdata == held_data &&
              m_wstrb == 4'b0011,
              "faulted write overwrote quarantined W payload");
        reset_downstream_and_clear_fault();
        pulse_status_clear();

        $display("TEST accepted_read_response_timeout_and_late_drain");
        auto_r = 1'b0;
        allow_ar = 1'b1;
        before_ar = downstream_ar_count;
        axil_read(ALLOW_BASE + 32'h0000_000c, read_data, response);
        check(response == 2'b10, "read response timeout mismatch");
        check(downstream_ar_count == before_ar + 1,
              "response-timeout AR was not accepted downstream");
        check(faulted && fault_code == 3'd3 && !fault_write,
              "read response timeout record mismatch");
        check(!m_arvalid, "accepted timed-out AR remained valid");
        before_r = downstream_r_count;
        manual_rdata = 32'hfeed_face;
        manual_rresp = 2'b00;
        manual_rvalid = 1'b1;
        repeat (2) @(negedge clk);
        check(m_rready, "faulted guard did not drain late R");
        manual_rvalid = 1'b0;
        repeat (2) @(negedge clk);
        check(downstream_r_count > before_r,
              "late R response was not drained");
        check(!s_rvalid, "late R response leaked upstream");
        reset_downstream_and_clear_fault();
        auto_r = 1'b1;
        pulse_status_clear();

        configured_rdata = 32'h7654_3210;
        axil_read(ALLOW_BASE, read_data, response);
        check(response == 2'b00 && read_data == 32'h7654_3210,
              "final read recovery failed");
        check(!guard_sticky && !timeout_sticky &&
              !downstream_error_sticky && !fault_valid,
              "status clear left sticky fault state");

        if (failures == 0) begin
            $display("PASS: %0d checks", checks);
            $finish;
        end else begin
            $fatal(1, "FAIL: %0d of %0d checks failed", failures, checks);
        end
    end

endmodule

`default_nettype wire
