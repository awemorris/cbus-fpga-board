`timescale 1ns/1ps
`default_nettype none

module tb_riscv_core_ip_stub;
    localparam integer AXI_ADDR_WIDTH = 32;
    localparam integer AXI_DATA_WIDTH = 32;
    localparam integer AXI_ID_WIDTH = 2;

    logic core_clk_i = 1'b0;
    logic core_rst_n_i;
    logic core_enable_i;
    logic [31:0] boot_addr_i;
    logic [31:0] hart_id_i;
    logic irq_software_i, irq_timer_i, irq_external_i;

    logic core_sleep_o, core_halted_o, core_trap_valid_o;
    logic [31:0] core_trap_cause_o, core_trap_pc_o;

    logic [AXI_ID_WIDTH-1:0] m_axi_awid_o;
    logic [AXI_ADDR_WIDTH-1:0] m_axi_awaddr_o;
    logic [7:0] m_axi_awlen_o;
    logic [2:0] m_axi_awsize_o;
    logic [1:0] m_axi_awburst_o;
    logic m_axi_awlock_o;
    logic [3:0] m_axi_awcache_o;
    logic [2:0] m_axi_awprot_o;
    logic [3:0] m_axi_awqos_o;
    logic m_axi_awvalid_o, m_axi_awready_i;

    logic [AXI_DATA_WIDTH-1:0] m_axi_wdata_o;
    logic [(AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb_o;
    logic m_axi_wlast_o, m_axi_wvalid_o, m_axi_wready_i;
    logic [AXI_ID_WIDTH-1:0] m_axi_bid_i;
    logic [1:0] m_axi_bresp_i;
    logic m_axi_bvalid_i, m_axi_bready_o;

    logic [AXI_ID_WIDTH-1:0] m_axi_arid_o;
    logic [AXI_ADDR_WIDTH-1:0] m_axi_araddr_o;
    logic [7:0] m_axi_arlen_o;
    logic [2:0] m_axi_arsize_o;
    logic [1:0] m_axi_arburst_o;
    logic m_axi_arlock_o;
    logic [3:0] m_axi_arcache_o;
    logic [2:0] m_axi_arprot_o;
    logic [3:0] m_axi_arqos_o;
    logic m_axi_arvalid_o, m_axi_arready_i;

    logic [AXI_ID_WIDTH-1:0] m_axi_rid_i;
    logic [AXI_DATA_WIDTH-1:0] m_axi_rdata_i;
    logic [1:0] m_axi_rresp_i;
    logic m_axi_rlast_i, m_axi_rvalid_i, m_axi_rready_o;

    integer checks = 0;

    always #5 core_clk_i = ~core_clk_i;

    riscv_core_ip_stub #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH)
    ) dut (
        .core_clk_i(core_clk_i),
        .core_rst_n_i(core_rst_n_i),
        .core_enable_i(core_enable_i),
        .boot_addr_i(boot_addr_i),
        .hart_id_i(hart_id_i),
        .irq_software_i(irq_software_i),
        .irq_timer_i(irq_timer_i),
        .irq_external_i(irq_external_i),
        .core_sleep_o(core_sleep_o),
        .core_halted_o(core_halted_o),
        .core_trap_valid_o(core_trap_valid_o),
        .core_trap_cause_o(core_trap_cause_o),
        .core_trap_pc_o(core_trap_pc_o),
        .m_axi_awid_o(m_axi_awid_o),
        .m_axi_awaddr_o(m_axi_awaddr_o),
        .m_axi_awlen_o(m_axi_awlen_o),
        .m_axi_awsize_o(m_axi_awsize_o),
        .m_axi_awburst_o(m_axi_awburst_o),
        .m_axi_awlock_o(m_axi_awlock_o),
        .m_axi_awcache_o(m_axi_awcache_o),
        .m_axi_awprot_o(m_axi_awprot_o),
        .m_axi_awqos_o(m_axi_awqos_o),
        .m_axi_awvalid_o(m_axi_awvalid_o),
        .m_axi_awready_i(m_axi_awready_i),
        .m_axi_wdata_o(m_axi_wdata_o),
        .m_axi_wstrb_o(m_axi_wstrb_o),
        .m_axi_wlast_o(m_axi_wlast_o),
        .m_axi_wvalid_o(m_axi_wvalid_o),
        .m_axi_wready_i(m_axi_wready_i),
        .m_axi_bid_i(m_axi_bid_i),
        .m_axi_bresp_i(m_axi_bresp_i),
        .m_axi_bvalid_i(m_axi_bvalid_i),
        .m_axi_bready_o(m_axi_bready_o),
        .m_axi_arid_o(m_axi_arid_o),
        .m_axi_araddr_o(m_axi_araddr_o),
        .m_axi_arlen_o(m_axi_arlen_o),
        .m_axi_arsize_o(m_axi_arsize_o),
        .m_axi_arburst_o(m_axi_arburst_o),
        .m_axi_arlock_o(m_axi_arlock_o),
        .m_axi_arcache_o(m_axi_arcache_o),
        .m_axi_arprot_o(m_axi_arprot_o),
        .m_axi_arqos_o(m_axi_arqos_o),
        .m_axi_arvalid_o(m_axi_arvalid_o),
        .m_axi_arready_i(m_axi_arready_i),
        .m_axi_rid_i(m_axi_rid_i),
        .m_axi_rdata_i(m_axi_rdata_i),
        .m_axi_rresp_i(m_axi_rresp_i),
        .m_axi_rlast_i(m_axi_rlast_i),
        .m_axi_rvalid_i(m_axi_rvalid_i),
        .m_axi_rready_o(m_axi_rready_o)
    );

    task automatic check(input logic condition, input string name);
        begin
            if (condition !== 1'b1) begin
                $display("FAIL: %s", name);
                $fatal(1);
            end
            checks = checks + 1;
        end
    endtask

    task automatic check_safe(input string state_name);
        begin
            #1;
            check({m_axi_awid_o, m_axi_awaddr_o, m_axi_awlen_o,
                   m_axi_awsize_o, m_axi_awburst_o, m_axi_awlock_o,
                   m_axi_awcache_o, m_axi_awprot_o, m_axi_awqos_o,
                   m_axi_awvalid_o} == '0, {state_name, ": AW inactive"});
            check({m_axi_wdata_o, m_axi_wstrb_o, m_axi_wlast_o,
                   m_axi_wvalid_o, m_axi_bready_o} == '0,
                  {state_name, ": W/B inactive"});
            check({m_axi_arid_o, m_axi_araddr_o, m_axi_arlen_o,
                   m_axi_arsize_o, m_axi_arburst_o, m_axi_arlock_o,
                   m_axi_arcache_o, m_axi_arprot_o, m_axi_arqos_o,
                   m_axi_arvalid_o} == '0, {state_name, ": AR inactive"});
            check(m_axi_rready_o == 1'b0, {state_name, ": R inactive"});
            check({core_sleep_o, core_trap_valid_o, core_trap_cause_o,
                   core_trap_pc_o} == '0 && core_halted_o == 1'b1,
                  {state_name, ": diagnostic safe"});
            check(!$isunknown({core_sleep_o, core_halted_o, core_trap_valid_o,
                   core_trap_cause_o, core_trap_pc_o, m_axi_awid_o,
                   m_axi_awaddr_o, m_axi_awlen_o, m_axi_awsize_o,
                   m_axi_awburst_o, m_axi_awlock_o, m_axi_awcache_o,
                   m_axi_awprot_o, m_axi_awqos_o, m_axi_awvalid_o,
                   m_axi_wdata_o, m_axi_wstrb_o, m_axi_wlast_o,
                   m_axi_wvalid_o, m_axi_bready_o, m_axi_arid_o,
                   m_axi_araddr_o, m_axi_arlen_o, m_axi_arsize_o,
                   m_axi_arburst_o, m_axi_arlock_o, m_axi_arcache_o,
                   m_axi_arprot_o, m_axi_arqos_o, m_axi_arvalid_o,
                   m_axi_rready_o}), {state_name, ": no unknown output"});
        end
    endtask

    initial begin
        core_rst_n_i = 1'b0;
        core_enable_i = 1'b0;
        boot_addr_i = 32'h0000_0000;
        hart_id_i = 32'h0000_0000;
        irq_software_i = 1'b0;
        irq_timer_i = 1'b0;
        irq_external_i = 1'b0;
        m_axi_awready_i = 1'b0;
        m_axi_wready_i = 1'b0;
        m_axi_bid_i = '0;
        m_axi_bresp_i = 2'b00;
        m_axi_bvalid_i = 1'b0;
        m_axi_arready_i = 1'b0;
        m_axi_rid_i = '0;
        m_axi_rdata_i = '0;
        m_axi_rresp_i = 2'b00;
        m_axi_rlast_i = 1'b0;
        m_axi_rvalid_i = 1'b0;
        check_safe("reset defaults");

        core_rst_n_i = 1'b1;
        boot_addr_i = 32'h1234_5678;
        hart_id_i = 32'h89ab_cdef;
        check_safe("disabled with identity inputs");

        core_enable_i = 1'b1;
        irq_software_i = 1'b1;
        irq_timer_i = 1'b1;
        irq_external_i = 1'b1;
        check_safe("enabled with all interrupts");

        m_axi_awready_i = 1'b1;
        m_axi_wready_i = 1'b1;
        m_axi_bid_i = 2'b11;
        m_axi_bresp_i = 2'b11;
        m_axi_bvalid_i = 1'b1;
        m_axi_arready_i = 1'b1;
        m_axi_rid_i = 2'b10;
        m_axi_rdata_i = 32'hdead_beef;
        m_axi_rresp_i = 2'b10;
        m_axi_rlast_i = 1'b1;
        m_axi_rvalid_i = 1'b1;
        check_safe("unsolicited AXI responses");

        core_rst_n_i = 1'b0;
        core_enable_i = 1'b0;
        boot_addr_i = 32'hffff_ffff;
        hart_id_i = 32'hffff_ffff;
        check_safe("reset under active inputs");

        $display("tb_riscv_core_ip_stub: PASS: %0d checks", checks);
        $finish;
    end

endmodule

`default_nettype wire
