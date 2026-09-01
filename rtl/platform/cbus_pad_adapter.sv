`timescale 1ns/1ps
`default_nettype none

// Logical-to-carrier safety boundary.  A request is never sufficient by
// itself: every physical drive path is additionally gated by drive_permit_o.
// The external carrier must pull every active-low LVC OE pin High while the
// FPGA is unconfigured; RTL cannot guarantee configuration-time pin state.
module cbus_pad_adapter #(
    parameter logic DATA_CARD_TO_HOST_DIR_LEVEL = 1'b1,
    parameter logic ADDR_CARD_TO_HOST_DIR_LEVEL = 1'b1,
    parameter logic CMD_CARD_TO_HOST_DIR_LEVEL  = 1'b1
) (
    input  logic power_good,
    input  logic config_done,
    input  logic clock_locked,
    input  logic reset_released,
    input  logic external_safety_latch,
    input  logic bus_permit,

    input  logic data_dir_req,
    input  logic data_oe_req,
    input  logic iordy_oe_req,
    input  logic irq_oe_req,
    input  logic word_oe_req,
    input  logic addr_dir_req,
    input  logic addr_oe_req,
    input  logic cmd_dir_req,
    input  logic cmd_oe_req,

    output logic drive_permit_o,
    output logic data_pad_oe,
    output logic addr_pad_oe,
    output logic cmd_pad_oe,
    output logic data_dir,
    output logic data_oe_n,
    output logic iordy_oe_n,
    output logic irq_oe_n,
    output logic word_oe_n,
    output logic addr_dir,
    output logic addr_oe_n,
    output logic cmd_dir,
    output logic cmd_oe_n
);

    always_comb begin
        drive_permit_o =
            power_good && config_done && clock_locked && reset_released &&
            external_safety_latch && bus_permit;

        data_pad_oe = drive_permit_o && data_oe_req;
        addr_pad_oe = drive_permit_o && addr_oe_req;
        cmd_pad_oe  = drive_permit_o && cmd_oe_req;

        // A request value of one means card-to-host.  When unsafe, force the
        // receiver direction before disabling the external transceiver.
        data_dir = drive_permit_o
            ? (data_dir_req ? DATA_CARD_TO_HOST_DIR_LEVEL
                            : ~DATA_CARD_TO_HOST_DIR_LEVEL)
            : ~DATA_CARD_TO_HOST_DIR_LEVEL;
        addr_dir = drive_permit_o
            ? (addr_dir_req ? ADDR_CARD_TO_HOST_DIR_LEVEL
                            : ~ADDR_CARD_TO_HOST_DIR_LEVEL)
            : ~ADDR_CARD_TO_HOST_DIR_LEVEL;
        cmd_dir = drive_permit_o
            ? (cmd_dir_req ? CMD_CARD_TO_HOST_DIR_LEVEL
                           : ~CMD_CARD_TO_HOST_DIR_LEVEL)
            : ~CMD_CARD_TO_HOST_DIR_LEVEL;

        data_oe_n  = ~(drive_permit_o && data_oe_req);
        iordy_oe_n = ~(drive_permit_o && iordy_oe_req);
        irq_oe_n   = ~(drive_permit_o && irq_oe_req);
        word_oe_n  = ~(drive_permit_o && word_oe_req);
        addr_oe_n  = ~(drive_permit_o && addr_oe_req);
        cmd_oe_n   = ~(drive_permit_o && cmd_oe_req);
    end

endmodule

`default_nettype wire
