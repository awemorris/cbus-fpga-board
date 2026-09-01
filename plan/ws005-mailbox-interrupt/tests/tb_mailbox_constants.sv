`timescale 1ns/1ps
`default_nettype none

module tb_mailbox_constants;
    import cbus_mailbox_regs_pkg::*;

    integer checks;

    task automatic check_value(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (!condition) begin
                $error("FAIL: %s", message);
                $fatal(1);
            end
        end
    endtask

    initial begin
        checks = 0;
        check_value(ABI_VERSION == 32'h0000_0001, "ABI version");
        check_value(INTR_BASE == 32'h1000_2000, "interrupt base");
        check_value(MBX_BASE == 32'h1000_3000, "mailbox base");
        check_value(MBX_FIFO_DEPTH == 32'd8, "FIFO depth");
        check_value(MBX_ENTRY_BITS == 32'd32, "entry width");
        check_value(MBX_H2C_HOST_PUSH_ADDR == 32'h1000_3018, "H2C push address");
        check_value(MBX_C2H_HOST_POP_ADDR == 32'h1000_303c, "C2H pop address");
        check_value(EVENT_H2C_DOORBELL_MASK == 32'h0000_0001, "H2C event mask");
        check_value(EVENT_C2H_DOORBELL_MASK == 32'h0000_0002, "C2H event mask");
        check_value(INTR_CPU_PENDING_VALID_SOURCES_MASK == 32'h00ff_037d,
               "CPU valid source mask");
        check_value(INTR_HOST_PENDING_VALID_SOURCES_MASK == 32'h0000_0002,
               "host valid source mask");
        check_value(CBUS_ALIAS_HOST_DIAG_ACK_OFFSET == 32'h0000_001e,
               "last C-bus alias");
        $display("tb_mailbox_constants: PASS: %0d checks", checks);
        $finish;
    end
endmodule

`default_nettype wire
