`timescale 1ns/1ps
`default_nettype none

module cbus_control_subsystem #(
    parameter logic [31:0] SYSTEM_BASE_ADDR = 32'h1000_0000
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        cbus_timeout_sticky_async,
    input  logic        cbus_invalid_sticky_async,
    input  logic        cbus_backend_error_sticky_async,
    input  logic        cbus_abort_sticky_async,
    input  logic        guard_faulted,
    input  logic        guard_reject_sticky,
    input  logic        guard_timeout_sticky,
    input  logic        guard_downstream_error_sticky,
    input  logic        guard_fault_valid,
    input  logic [2:0]  guard_fault_code,
    input  logic        guard_fault_write,
    output logic [31:0] system_scratch_value,
    output logic        mailbox_cpu_irq_active,
    output logic        mailbox_host_irq_active,

    input  logic [31:0] s_axil_awaddr,
    input  logic [2:0]  s_axil_awprot,
    input  logic        s_axil_awvalid,
    output logic        s_axil_awready,
    input  logic [31:0] s_axil_wdata,
    input  logic [3:0]  s_axil_wstrb,
    input  logic        s_axil_wvalid,
    output logic        s_axil_wready,
    output logic [1:0]  s_axil_bresp,
    output logic        s_axil_bvalid,
    input  logic        s_axil_bready,
    input  logic [31:0] s_axil_araddr,
    input  logic [2:0]  s_axil_arprot,
    input  logic        s_axil_arvalid,
    output logic        s_axil_arready,
    output logic [31:0] s_axil_rdata,
    output logic [1:0]  s_axil_rresp,
    output logic        s_axil_rvalid,
    input  logic        s_axil_rready
);

    logic guard_faulted_d;
    logic [31:0] external_cpu_event_set;
    logic [31:0] cpu_pending;
    logic [31:0] cpu_mask;
    logic [31:0] cpu_active;
    logic [31:0] host_pending;
    logic [31:0] host_mask;
    logic [31:0] host_active;

    logic [31:0] sys_awaddr, intr_awaddr, mbx_awaddr;
    logic [2:0] sys_awprot, intr_awprot, mbx_awprot;
    logic sys_awvalid, intr_awvalid, mbx_awvalid;
    logic sys_awready, intr_awready, mbx_awready;
    logic [31:0] sys_wdata, intr_wdata, mbx_wdata;
    logic [3:0] sys_wstrb, intr_wstrb, mbx_wstrb;
    logic sys_wvalid, intr_wvalid, mbx_wvalid;
    logic sys_wready, intr_wready, mbx_wready;
    logic [1:0] sys_bresp, intr_bresp, mbx_bresp;
    logic sys_bvalid, intr_bvalid, mbx_bvalid;
    logic sys_bready, intr_bready, mbx_bready;
    logic [31:0] sys_araddr, intr_araddr, mbx_araddr;
    logic [2:0] sys_arprot, intr_arprot, mbx_arprot;
    logic sys_arvalid, intr_arvalid, mbx_arvalid;
    logic sys_arready, intr_arready, mbx_arready;
    logic [31:0] sys_rdata, intr_rdata, mbx_rdata;
    logic [1:0] sys_rresp, intr_rresp, mbx_rresp;
    logic sys_rvalid, intr_rvalid, mbx_rvalid;
    logic sys_rready, intr_rready, mbx_rready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            guard_faulted_d <= 1'b0;
        else
            guard_faulted_d <= guard_faulted;
    end

    always_comb begin
        external_cpu_event_set = 32'h0000_0000;
        if (guard_faulted && !guard_faulted_d)
            external_cpu_event_set =
                cbus_mailbox_regs_pkg::EVENT_GUARD_FAULT_MASK;
    end

    axil_control_fabric_1x3 fabric (
        .clk(clk), .rst_n(rst_n),
        .s_axil_awaddr(s_axil_awaddr), .s_axil_awprot(s_axil_awprot),
        .s_axil_awvalid(s_axil_awvalid), .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata), .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid), .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp), .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr), .s_axil_arprot(s_axil_arprot),
        .s_axil_arvalid(s_axil_arvalid), .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata), .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid), .s_axil_rready(s_axil_rready),
        .m0_axil_awaddr(sys_awaddr), .m0_axil_awprot(sys_awprot),
        .m0_axil_awvalid(sys_awvalid), .m0_axil_awready(sys_awready),
        .m0_axil_wdata(sys_wdata), .m0_axil_wstrb(sys_wstrb),
        .m0_axil_wvalid(sys_wvalid), .m0_axil_wready(sys_wready),
        .m0_axil_bresp(sys_bresp), .m0_axil_bvalid(sys_bvalid), .m0_axil_bready(sys_bready),
        .m0_axil_araddr(sys_araddr), .m0_axil_arprot(sys_arprot),
        .m0_axil_arvalid(sys_arvalid), .m0_axil_arready(sys_arready),
        .m0_axil_rdata(sys_rdata), .m0_axil_rresp(sys_rresp),
        .m0_axil_rvalid(sys_rvalid), .m0_axil_rready(sys_rready),
        .m1_axil_awaddr(intr_awaddr), .m1_axil_awprot(intr_awprot),
        .m1_axil_awvalid(intr_awvalid), .m1_axil_awready(intr_awready),
        .m1_axil_wdata(intr_wdata), .m1_axil_wstrb(intr_wstrb),
        .m1_axil_wvalid(intr_wvalid), .m1_axil_wready(intr_wready),
        .m1_axil_bresp(intr_bresp), .m1_axil_bvalid(intr_bvalid), .m1_axil_bready(intr_bready),
        .m1_axil_araddr(intr_araddr), .m1_axil_arprot(intr_arprot),
        .m1_axil_arvalid(intr_arvalid), .m1_axil_arready(intr_arready),
        .m1_axil_rdata(intr_rdata), .m1_axil_rresp(intr_rresp),
        .m1_axil_rvalid(intr_rvalid), .m1_axil_rready(intr_rready),
        .m2_axil_awaddr(mbx_awaddr), .m2_axil_awprot(mbx_awprot),
        .m2_axil_awvalid(mbx_awvalid), .m2_axil_awready(mbx_awready),
        .m2_axil_wdata(mbx_wdata), .m2_axil_wstrb(mbx_wstrb),
        .m2_axil_wvalid(mbx_wvalid), .m2_axil_wready(mbx_wready),
        .m2_axil_bresp(mbx_bresp), .m2_axil_bvalid(mbx_bvalid), .m2_axil_bready(mbx_bready),
        .m2_axil_araddr(mbx_araddr), .m2_axil_arprot(mbx_arprot),
        .m2_axil_arvalid(mbx_arvalid), .m2_axil_arready(mbx_arready),
        .m2_axil_rdata(mbx_rdata), .m2_axil_rresp(mbx_rresp),
        .m2_axil_rvalid(mbx_rvalid), .m2_axil_rready(mbx_rready)
    );

    axil_system_csr #(.BASE_ADDR(SYSTEM_BASE_ADDR)) system_csr (
        .clk(clk), .rst_n(rst_n),
        .cbus_timeout_sticky_async(cbus_timeout_sticky_async),
        .cbus_invalid_sticky_async(cbus_invalid_sticky_async),
        .cbus_backend_error_sticky_async(cbus_backend_error_sticky_async),
        .cbus_abort_sticky_async(cbus_abort_sticky_async),
        .guard_faulted(guard_faulted), .guard_reject_sticky(guard_reject_sticky),
        .guard_timeout_sticky(guard_timeout_sticky),
        .guard_downstream_error_sticky(guard_downstream_error_sticky),
        .guard_fault_valid(guard_fault_valid), .guard_fault_code(guard_fault_code),
        .guard_fault_write(guard_fault_write), .scratch_value(system_scratch_value),
        .s_axil_awaddr(sys_awaddr), .s_axil_awprot(sys_awprot),
        .s_axil_awvalid(sys_awvalid), .s_axil_awready(sys_awready),
        .s_axil_wdata(sys_wdata), .s_axil_wstrb(sys_wstrb),
        .s_axil_wvalid(sys_wvalid), .s_axil_wready(sys_wready),
        .s_axil_bresp(sys_bresp), .s_axil_bvalid(sys_bvalid), .s_axil_bready(sys_bready),
        .s_axil_araddr(sys_araddr), .s_axil_arprot(sys_arprot),
        .s_axil_arvalid(sys_arvalid), .s_axil_arready(sys_arready),
        .s_axil_rdata(sys_rdata), .s_axil_rresp(sys_rresp),
        .s_axil_rvalid(sys_rvalid), .s_axil_rready(sys_rready)
    );

    mailbox_interrupt_subsystem mailbox_interrupt (
        .clk(clk), .rst_n(rst_n),
        .external_cpu_event_set(external_cpu_event_set),
        .external_host_event_set(32'h0000_0000),
        .cpu_pending(cpu_pending), .cpu_mask(cpu_mask), .cpu_active(cpu_active),
        .cpu_irq_active(mailbox_cpu_irq_active),
        .host_pending(host_pending), .host_mask(host_mask), .host_active(host_active),
        .host_irq_active(mailbox_host_irq_active),
        .intr_axil_awaddr(intr_awaddr), .intr_axil_awprot(intr_awprot),
        .intr_axil_awvalid(intr_awvalid), .intr_axil_awready(intr_awready),
        .intr_axil_wdata(intr_wdata), .intr_axil_wstrb(intr_wstrb),
        .intr_axil_wvalid(intr_wvalid), .intr_axil_wready(intr_wready),
        .intr_axil_bresp(intr_bresp), .intr_axil_bvalid(intr_bvalid),
        .intr_axil_bready(intr_bready),
        .intr_axil_araddr(intr_araddr), .intr_axil_arprot(intr_arprot),
        .intr_axil_arvalid(intr_arvalid), .intr_axil_arready(intr_arready),
        .intr_axil_rdata(intr_rdata), .intr_axil_rresp(intr_rresp),
        .intr_axil_rvalid(intr_rvalid), .intr_axil_rready(intr_rready),
        .mbx_axil_awaddr(mbx_awaddr), .mbx_axil_awprot(mbx_awprot),
        .mbx_axil_awvalid(mbx_awvalid), .mbx_axil_awready(mbx_awready),
        .mbx_axil_wdata(mbx_wdata), .mbx_axil_wstrb(mbx_wstrb),
        .mbx_axil_wvalid(mbx_wvalid), .mbx_axil_wready(mbx_wready),
        .mbx_axil_bresp(mbx_bresp), .mbx_axil_bvalid(mbx_bvalid),
        .mbx_axil_bready(mbx_bready),
        .mbx_axil_araddr(mbx_araddr), .mbx_axil_arprot(mbx_arprot),
        .mbx_axil_arvalid(mbx_arvalid), .mbx_axil_arready(mbx_arready),
        .mbx_axil_rdata(mbx_rdata), .mbx_axil_rresp(mbx_rresp),
        .mbx_axil_rvalid(mbx_rvalid), .mbx_axil_rready(mbx_rready)
    );

    wire unused_router_state = ^{cpu_pending, cpu_mask, cpu_active,
                                 host_pending, host_mask, host_active};

endmodule

`default_nettype wire
