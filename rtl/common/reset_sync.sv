`timescale 1ns/1ps
`default_nettype none

module reset_sync (
    input  logic clk,
    input  logic async_rst_n,
    output logic sync_rst_n
);

    (* async_reg = "true" *) logic [1:0] release_sync;

    always_ff @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n)
            release_sync <= 2'b00;
        else
            release_sync <= {release_sync[0], 1'b1};
    end

    assign sync_rst_n = release_sync[1];

endmodule

`default_nettype wire
