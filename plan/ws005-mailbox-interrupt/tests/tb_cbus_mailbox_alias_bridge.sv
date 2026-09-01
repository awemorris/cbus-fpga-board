`timescale 1ns/1ps
`default_nettype none

module tb_cbus_mailbox_alias_bridge;
    localparam logic [15:0] MBX_BASE = 16'h0200;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #5 clk = ~clk;

    logic req_valid, req_ready, req_write;
    logic [7:0] req_tag, rsp_tag;
    logic [23:0] req_addr;
    logic [15:0] req_wdata, rsp_rdata;
    logic [1:0] req_be;
    logic rsp_valid, rsp_ready, rsp_error;
    logic [31:0] awaddr, wdata, araddr, rdata;
    logic [2:0] awprot, arprot;
    logic awvalid, awready, wvalid, wready, bvalid, bready;
    logic [3:0] wstrb;
    logic [1:0] bresp, rresp;
    logic arvalid, arready, rvalid, rready;
    logic aw_seen, w_seen;
    logic [31:0] aw_hold, wdata_hold;
    logic [3:0] wstrb_hold;
    logic inject_read_error, inject_write_error;
    integer checks, read_count, write_count;
    logic [31:0] read_log [0:127];
    logic [31:0] write_addr_log [0:127];
    logic [31:0] write_data_log [0:127];
    logic [3:0] write_strb_log [0:127];

    cbus_to_axil_bridge #(
        .CBUS_IO_BASE_ADDR(16'h00d0),
        .CBUS_IO_ADDR_MASK(16'hfff8),
        .CBUS_MBX_ENABLE(1'b1),
        .CBUS_MBX_IO_BASE(MBX_BASE)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .req_valid(req_valid), .req_ready(req_ready), .req_tag(req_tag),
        .req_space_memory(1'b0),
        .req_write(req_write), .req_addr(req_addr), .req_wdata(req_wdata),
        .req_be(req_be), .rsp_valid(rsp_valid), .rsp_ready(rsp_ready),
        .rsp_tag(rsp_tag), .rsp_rdata(rsp_rdata), .rsp_error(rsp_error),
        .m_axil_awaddr(awaddr), .m_axil_awprot(awprot),
        .m_axil_awvalid(awvalid), .m_axil_awready(awready),
        .m_axil_wdata(wdata), .m_axil_wstrb(wstrb),
        .m_axil_wvalid(wvalid), .m_axil_wready(wready),
        .m_axil_bresp(bresp), .m_axil_bvalid(bvalid), .m_axil_bready(bready),
        .m_axil_araddr(araddr), .m_axil_arprot(arprot),
        .m_axil_arvalid(arvalid), .m_axil_arready(arready),
        .m_axil_rdata(rdata), .m_axil_rresp(rresp),
        .m_axil_rvalid(rvalid), .m_axil_rready(rready)
    );

    function automatic [31:0] model_read(input logic [31:0] address);
        begin
            case (address)
                cbus_mailbox_regs_pkg::MBX_H2C_STATUS_ADDR: model_read = 32'h0001_abcd;
                cbus_mailbox_regs_pkg::MBX_C2H_STATUS_ADDR: model_read = 32'h0002_1234;
                cbus_mailbox_regs_pkg::MBX_DOORBELL_STATUS_ADDR: model_read = 32'h0002_0003;
                default: model_read = {address[15:0] ^ 16'h5a5a,
                                       address[15:0] ^ 16'ha5a5};
            endcase
        end
    endfunction

    always_comb begin
        awready = !bvalid;
        wready = !bvalid;
        arready = !rvalid;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_seen <= 1'b0;
            w_seen <= 1'b0;
            aw_hold <= 32'h0;
            wdata_hold <= 32'h0;
            wstrb_hold <= 4'h0;
            bvalid <= 1'b0;
            bresp <= 2'b00;
            rvalid <= 1'b0;
            rdata <= 32'h0;
            rresp <= 2'b00;
            read_count <= 0;
            write_count <= 0;
            inject_read_error <= 1'b0;
            inject_write_error <= 1'b0;
        end else begin
            if (bvalid && bready)
                bvalid <= 1'b0;
            if (rvalid && rready)
                rvalid <= 1'b0;
            if (awvalid && awready) begin
                aw_seen <= 1'b1;
                aw_hold <= awaddr;
            end
            if (wvalid && wready) begin
                w_seen <= 1'b1;
                wdata_hold <= wdata;
                wstrb_hold <= wstrb;
            end
            if (!bvalid && (aw_seen || (awvalid && awready)) &&
                (w_seen || (wvalid && wready))) begin
                write_addr_log[write_count] <= aw_seen ? aw_hold : awaddr;
                write_data_log[write_count] <= w_seen ? wdata_hold : wdata;
                write_strb_log[write_count] <= w_seen ? wstrb_hold : wstrb;
                write_count <= write_count + 1;
                aw_seen <= 1'b0;
                w_seen <= 1'b0;
                bresp <= inject_write_error ? 2'b10 : 2'b00;
                inject_write_error <= 1'b0;
                bvalid <= 1'b1;
            end
            if (arvalid && arready) begin
                read_log[read_count] <= araddr;
                read_count <= read_count + 1;
                rdata <= model_read(araddr);
                rresp <= inject_read_error ? 2'b10 : 2'b00;
                inject_read_error <= 1'b0;
                rvalid <= 1'b1;
            end
        end
    end

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (!condition) begin
                $display("FAIL check=%0d %s", checks, message);
                $fatal(1);
            end
        end
    endtask

    task automatic request(
        input logic write_op,
        input logic [15:0] address,
        input logic [15:0] data,
        input logic [1:0] be,
        output logic [15:0] result,
        output logic error_result
    );
        integer timeout;
        begin
            @(negedge clk);
            while (!req_ready) @(negedge clk);
            req_tag = req_tag + 1'b1;
            req_write = write_op;
            req_addr = {8'h00, address};
            req_wdata = data;
            req_be = be;
            req_valid = 1'b1;
            @(posedge clk);
            #1 req_valid = 1'b0;
            timeout = 0;
            while (!rsp_valid && timeout < 100) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            check(rsp_valid, "request completed");
            check(rsp_tag == req_tag, "response tag preserved");
            result = rsp_rdata;
            error_result = rsp_error;
            @(posedge clk);
        end
    endtask

    function automatic [31:0] expected_alias_addr(input logic [4:0] offset);
        begin
            case (offset)
                5'h00: expected_alias_addr = cbus_mailbox_regs_pkg::MBX_H2C_HOST_LO_ADDR;
                5'h02: expected_alias_addr = cbus_mailbox_regs_pkg::MBX_H2C_HOST_HI_ADDR;
                5'h04: expected_alias_addr = cbus_mailbox_regs_pkg::MBX_H2C_HOST_PUSH_ADDR;
                5'h06: expected_alias_addr = cbus_mailbox_regs_pkg::MBX_H2C_DOORBELL_SET_ADDR;
                5'h08, 5'h0a: expected_alias_addr = cbus_mailbox_regs_pkg::MBX_H2C_STATUS_ADDR;
                5'h0c: expected_alias_addr = cbus_mailbox_regs_pkg::MBX_C2H_HOST_LO_ADDR;
                5'h0e: expected_alias_addr = cbus_mailbox_regs_pkg::MBX_C2H_HOST_HI_ADDR;
                5'h10: expected_alias_addr = cbus_mailbox_regs_pkg::MBX_C2H_HOST_POP_ADDR;
                5'h12, 5'h14: expected_alias_addr = cbus_mailbox_regs_pkg::MBX_C2H_STATUS_ADDR;
                5'h16: expected_alias_addr = cbus_mailbox_regs_pkg::INTR_HOST_PENDING_ADDR;
                5'h18: expected_alias_addr = cbus_mailbox_regs_pkg::INTR_HOST_MASK_ADDR;
                default: expected_alias_addr = cbus_mailbox_regs_pkg::INTR_HOST_ACK_ADDR;
            endcase
        end
    endfunction

    initial begin
        logic [15:0] result;
        logic error_result;
        logic [31:0] expected_read;
        integer offset, before_count;
        checks = 0;
        req_valid = 1'b0;
        req_tag = 8'h00;
        req_write = 1'b0;
        req_addr = 24'h0;
        req_wdata = 16'h0;
        req_be = 2'b11;
        rsp_ready = 1'b1;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        request(1'b0, 16'h00d0, 16'h0, 2'b11, result, error_result);
        check(!error_result && read_log[read_count-1] == 32'h1000_0000,
              "System CSR mapping remains linear");

        for (offset = 0; offset <= 16'h1a; offset = offset + 2) begin
            before_count = read_count;
            request(1'b0, MBX_BASE + offset, 16'h0, 2'b11, result, error_result);
            check(!error_result && read_count == before_count + 1,
                  "alias read emits one AXI read");
            check(read_log[before_count] == expected_alias_addr(offset[4:0]),
                  "alias read address matches generated ABI");
            expected_read = model_read(expected_alias_addr(offset[4:0]));
            if ((offset == 16'h0a) || (offset == 16'h14))
                check(result == expected_read[31:16],
                      "status high alias selects upper half");
            else
                check(result == expected_read[15:0],
                      "alias read selects lower half");
        end

        before_count = read_count;
        request(1'b0, MBX_BASE + 16'h1c, 16'h0, 2'b11, result, error_result);
        check(!error_result && result[2:0] == 3'b111 && read_count == before_count + 3,
              "HOST_DIAG_STATUS combines three reads");
        check(read_log[before_count] == cbus_mailbox_regs_pkg::MBX_H2C_STATUS_ADDR &&
              read_log[before_count+1] == cbus_mailbox_regs_pkg::MBX_C2H_STATUS_ADDR &&
              read_log[before_count+2] == cbus_mailbox_regs_pkg::MBX_DOORBELL_STATUS_ADDR,
              "diagnostic read order is fixed");

        before_count = read_count;
        request(1'b0, MBX_BASE + 16'h1e, 16'h0, 2'b11, result, error_result);
        check(!error_result && result == 16'h0000 && read_count == before_count,
              "HOST_DIAG_ACK read is local zero");

        for (offset = 0; offset <= 16'h1a; offset = offset + 2) begin
            before_count = write_count;
            request(1'b1, MBX_BASE + offset, 16'h55aa, 2'b11, result, error_result);
            check(!error_result && write_count == before_count + 1,
                  "alias write emits one AXI write");
            check(write_addr_log[before_count] == expected_alias_addr(offset[4:0]) &&
                  write_data_log[before_count] == 32'h0000_55aa &&
                  write_strb_log[before_count] == 4'b0011,
                  "alias write address/data/strobe match ABI");
        end

        before_count = write_count;
        request(1'b1, MBX_BASE + 16'h04, 16'h0100, 2'b10, result, error_result);
        check(!error_result && write_count == before_count,
              "upper-byte-only W1P is no-op OKAY");

        before_count = write_count;
        request(1'b1, MBX_BASE + 16'h1c, 16'h0001, 2'b01, result, error_result);
        check(error_result && write_count == before_count,
              "HOST_DIAG_STATUS write is local error");

        before_count = write_count;
        request(1'b1, MBX_BASE + 16'h1e, 16'h0007, 2'b01, result, error_result);
        check(!error_result && write_count == before_count + 3,
              "HOST_DIAG_ACK expands selected bits");
        check(write_addr_log[before_count] == cbus_mailbox_regs_pkg::MBX_H2C_HOST_ERR_ACK_ADDR &&
              write_data_log[before_count] == 32'h0001_0000 &&
              write_addr_log[before_count+1] == cbus_mailbox_regs_pkg::MBX_C2H_HOST_ERR_ACK_ADDR &&
              write_data_log[before_count+1] == 32'h0002_0000 &&
              write_addr_log[before_count+2] == cbus_mailbox_regs_pkg::MBX_DOORBELL_COALESCED_ACK_ADDR &&
              write_data_log[before_count+2] == 32'h0002_0000,
              "diagnostic ack order and transforms are fixed");
        check(write_strb_log[before_count] == 4'b0100 &&
              write_strb_log[before_count+1] == 4'b0100 &&
              write_strb_log[before_count+2] == 4'b0100,
              "diagnostic ack uses byte lane two");

        inject_read_error = 1'b1;
        before_count = read_count;
        request(1'b0, MBX_BASE + 16'h1c, 16'h0, 2'b11, result, error_result);
        check(error_result && read_count == before_count + 1,
              "compound diagnostic stops on first AXI error");

        $display("PASS tb_cbus_mailbox_alias_bridge checks=%0d", checks);
        $finish;
    end

    wire unused_prot = ^{awprot, arprot};
endmodule

`default_nettype wire
