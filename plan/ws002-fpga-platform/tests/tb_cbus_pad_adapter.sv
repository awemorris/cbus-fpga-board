`timescale 1ns/1ps
`default_nettype none

module tb_cbus_pad_adapter;
    logic power_good, config_done, clock_locked, reset_released;
    logic external_safety_latch, bus_permit;
    logic data_dir_req, data_oe_req, iordy_oe_req, irq_oe_req, word_oe_req;
    logic addr_dir_req, addr_oe_req, cmd_dir_req, cmd_oe_req;
    logic drive_permit_o, data_pad_oe, addr_pad_oe, cmd_pad_oe;
    logic data_dir, data_oe_n, iordy_oe_n, irq_oe_n, word_oe_n;
    logic addr_dir, addr_oe_n, cmd_dir, cmd_oe_n;
    integer checks;
    integer mask;

    cbus_pad_adapter dut (.*);

    task automatic check(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL check=%0d: %s", checks, message);
                $fatal(1);
            end
        end
    endtask

    task automatic set_safety(input integer value);
        begin
            power_good = value[0];
            config_done = value[1];
            clock_locked = value[2];
            reset_released = value[3];
            external_safety_latch = value[4];
            bus_permit = value[5];
        end
    endtask

    initial begin
        checks = 0;
        data_dir_req = 1'b1;
        data_oe_req = 1'b1;
        iordy_oe_req = 1'b1;
        irq_oe_req = 1'b1;
        word_oe_req = 1'b1;
        addr_dir_req = 1'b1;
        addr_oe_req = 1'b1;
        cmd_dir_req = 1'b1;
        cmd_oe_req = 1'b1;

        for (mask = 0; mask < 64; mask = mask + 1) begin
            set_safety(mask);
            #1;
            check(drive_permit_o === (mask == 63), "six-input permit truth table");
            if (mask == 63) begin
                check({data_pad_oe, addr_pad_oe, cmd_pad_oe} === 3'b111, "safe pad enables");
                check({data_oe_n, iordy_oe_n, irq_oe_n, word_oe_n, addr_oe_n, cmd_oe_n} === 6'b000000,
                      "safe LVC enables");
                check({data_dir, addr_dir, cmd_dir} === 3'b111, "card-to-host direction");
            end else begin
                check({data_pad_oe, addr_pad_oe, cmd_pad_oe} === 3'b000, "unsafe pad High-Z");
                check({data_oe_n, iordy_oe_n, irq_oe_n, word_oe_n, addr_oe_n, cmd_oe_n} === 6'b111111,
                      "unsafe LVC High-Z");
                check({data_dir, addr_dir, cmd_dir} === 3'b000, "unsafe receiver direction");
            end
        end

        set_safety(63);
        for (mask = 0; mask < 512; mask = mask + 1) begin
            data_dir_req = mask[0]; data_oe_req = mask[1]; iordy_oe_req = mask[2];
            irq_oe_req = mask[3]; word_oe_req = mask[4]; addr_dir_req = mask[5];
            addr_oe_req = mask[6]; cmd_dir_req = mask[7]; cmd_oe_req = mask[8];
            #1;
            check(data_pad_oe === data_oe_req && data_oe_n === ~data_oe_req, "data request mapping");
            check(iordy_oe_n === ~iordy_oe_req && irq_oe_n === ~irq_oe_req, "response request mapping");
            check(word_oe_n === ~word_oe_req, "WORD request mapping");
            check(addr_pad_oe === addr_oe_req && addr_oe_n === ~addr_oe_req, "address request mapping");
            check(cmd_pad_oe === cmd_oe_req && cmd_oe_n === ~cmd_oe_req, "command request mapping");
            check({data_dir, addr_dir, cmd_dir} === {data_dir_req, addr_dir_req, cmd_dir_req},
                  "direction request mapping");
        end

        data_dir_req = 1'b1; data_oe_req = 1'b1; iordy_oe_req = 1'b1;
        irq_oe_req = 1'b1; word_oe_req = 1'b1; addr_dir_req = 1'b1;
        addr_oe_req = 1'b1; cmd_dir_req = 1'b1; cmd_oe_req = 1'b1;
        set_safety(63);
        #1;
        for (mask = 0; mask < 6; mask = mask + 1) begin
            set_safety(63 & ~(1 << mask));
            #0;
            check({data_pad_oe, addr_pad_oe, cmd_pad_oe} === 3'b000, "asynchronous permit withdrawal pad gate");
            check({data_oe_n, iordy_oe_n, irq_oe_n, word_oe_n, addr_oe_n, cmd_oe_n} === 6'b111111,
                  "asynchronous permit withdrawal LVC gate");
            set_safety(63);
            #1;
        end

        $display("PASS tb_cbus_pad_adapter checks=%0d", checks);
        $finish;
    end
endmodule

`default_nettype wire
