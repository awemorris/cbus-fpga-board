`timescale 1ns/1ps
`default_nettype none

// Safe, non-functional occupant for the user-owned RISC-V core slot.
// The production user core must expose the same port ABI under module name
// riscv_core_ip.  This stub deliberately accepts and issues no transaction.
module riscv_core_ip_stub #(
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer AXI_DATA_WIDTH = 32,
    parameter integer AXI_ID_WIDTH = 2
) (
    input  logic                          core_clk_i,
    input  logic                          core_rst_n_i,
    input  logic                          core_enable_i,
    input  logic [31:0]                   boot_addr_i,
    input  logic [31:0]                   hart_id_i,
    input  logic                          irq_software_i,
    input  logic                          irq_timer_i,
    input  logic                          irq_external_i,

    output logic                          core_sleep_o,
    output logic                          core_halted_o,
    output logic                          core_trap_valid_o,
    output logic [31:0]                   core_trap_cause_o,
    output logic [31:0]                   core_trap_pc_o,

    output logic [AXI_ID_WIDTH-1:0]       m_axi_awid_o,
    output logic [AXI_ADDR_WIDTH-1:0]     m_axi_awaddr_o,
    output logic [7:0]                    m_axi_awlen_o,
    output logic [2:0]                    m_axi_awsize_o,
    output logic [1:0]                    m_axi_awburst_o,
    output logic                          m_axi_awlock_o,
    output logic [3:0]                    m_axi_awcache_o,
    output logic [2:0]                    m_axi_awprot_o,
    output logic [3:0]                    m_axi_awqos_o,
    output logic                          m_axi_awvalid_o,
    input  logic                          m_axi_awready_i,

    output logic [AXI_DATA_WIDTH-1:0]     m_axi_wdata_o,
    output logic [(AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb_o,
    output logic                          m_axi_wlast_o,
    output logic                          m_axi_wvalid_o,
    input  logic                          m_axi_wready_i,

    input  logic [AXI_ID_WIDTH-1:0]       m_axi_bid_i,
    input  logic [1:0]                    m_axi_bresp_i,
    input  logic                          m_axi_bvalid_i,
    output logic                          m_axi_bready_o,

    output logic [AXI_ID_WIDTH-1:0]       m_axi_arid_o,
    output logic [AXI_ADDR_WIDTH-1:0]     m_axi_araddr_o,
    output logic [7:0]                    m_axi_arlen_o,
    output logic [2:0]                    m_axi_arsize_o,
    output logic [1:0]                    m_axi_arburst_o,
    output logic                          m_axi_arlock_o,
    output logic [3:0]                    m_axi_arcache_o,
    output logic [2:0]                    m_axi_arprot_o,
    output logic [3:0]                    m_axi_arqos_o,
    output logic                          m_axi_arvalid_o,
    input  logic                          m_axi_arready_i,

    input  logic [AXI_ID_WIDTH-1:0]       m_axi_rid_i,
    input  logic [AXI_DATA_WIDTH-1:0]     m_axi_rdata_i,
    input  logic [1:0]                    m_axi_rresp_i,
    input  logic                          m_axi_rlast_i,
    input  logic                          m_axi_rvalid_i,
    output logic                          m_axi_rready_o
);

    wire unused_inputs = ^{
        core_clk_i, core_rst_n_i, core_enable_i, boot_addr_i, hart_id_i,
        irq_software_i, irq_timer_i, irq_external_i, m_axi_awready_i,
        m_axi_wready_i, m_axi_bid_i, m_axi_bresp_i, m_axi_bvalid_i,
        m_axi_arready_i, m_axi_rid_i, m_axi_rdata_i, m_axi_rresp_i,
        m_axi_rlast_i, m_axi_rvalid_i
    };

    always_comb begin
        core_sleep_o = 1'b0;
        core_halted_o = 1'b1;
        core_trap_valid_o = 1'b0;
        core_trap_cause_o = 32'h0000_0000;
        core_trap_pc_o = 32'h0000_0000;

        m_axi_awid_o = '0;
        m_axi_awaddr_o = '0;
        m_axi_awlen_o = 8'h00;
        m_axi_awsize_o = 3'b000;
        m_axi_awburst_o = 2'b00;
        m_axi_awlock_o = 1'b0;
        m_axi_awcache_o = 4'b0000;
        m_axi_awprot_o = 3'b000;
        m_axi_awqos_o = 4'b0000;
        m_axi_awvalid_o = 1'b0;

        m_axi_wdata_o = '0;
        m_axi_wstrb_o = '0;
        m_axi_wlast_o = 1'b0;
        m_axi_wvalid_o = 1'b0;
        m_axi_bready_o = 1'b0;

        m_axi_arid_o = '0;
        m_axi_araddr_o = '0;
        m_axi_arlen_o = 8'h00;
        m_axi_arsize_o = 3'b000;
        m_axi_arburst_o = 2'b00;
        m_axi_arlock_o = 1'b0;
        m_axi_arcache_o = 4'b0000;
        m_axi_arprot_o = 3'b000;
        m_axi_arqos_o = 4'b0000;
        m_axi_arvalid_o = 1'b0;
        m_axi_rready_o = 1'b0;

        // Keep the combinational process sensitive to every stub input while
        // preserving constant-safe outputs for 0, 1, X and Z input states.
        if (unused_inputs)
            core_sleep_o = 1'b0;
    end

endmodule

`default_nettype wire
