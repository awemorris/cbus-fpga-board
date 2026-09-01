`timescale 1ns/1ps
`default_nettype none

module mailbox_interrupt_subsystem (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] external_cpu_event_set,
    input  logic [31:0] external_host_event_set,
    output logic [31:0] cpu_pending,
    output logic [31:0] cpu_mask,
    output logic [31:0] cpu_active,
    output logic        cpu_irq_active,
    output logic [31:0] host_pending,
    output logic [31:0] host_mask,
    output logic [31:0] host_active,
    output logic        host_irq_active,

    input  logic [31:0] intr_axil_awaddr,
    input  logic [2:0]  intr_axil_awprot,
    input  logic        intr_axil_awvalid,
    output logic        intr_axil_awready,
    input  logic [31:0] intr_axil_wdata,
    input  logic [3:0]  intr_axil_wstrb,
    input  logic        intr_axil_wvalid,
    output logic        intr_axil_wready,
    output logic [1:0]  intr_axil_bresp,
    output logic        intr_axil_bvalid,
    input  logic        intr_axil_bready,
    input  logic [31:0] intr_axil_araddr,
    input  logic [2:0]  intr_axil_arprot,
    input  logic        intr_axil_arvalid,
    output logic        intr_axil_arready,
    output logic [31:0] intr_axil_rdata,
    output logic [1:0]  intr_axil_rresp,
    output logic        intr_axil_rvalid,
    input  logic        intr_axil_rready,

    input  logic [31:0] mbx_axil_awaddr,
    input  logic [2:0]  mbx_axil_awprot,
    input  logic        mbx_axil_awvalid,
    output logic        mbx_axil_awready,
    input  logic [31:0] mbx_axil_wdata,
    input  logic [3:0]  mbx_axil_wstrb,
    input  logic        mbx_axil_wvalid,
    output logic        mbx_axil_wready,
    output logic [1:0]  mbx_axil_bresp,
    output logic        mbx_axil_bvalid,
    input  logic        mbx_axil_bready,
    input  logic [31:0] mbx_axil_araddr,
    input  logic [2:0]  mbx_axil_arprot,
    input  logic        mbx_axil_arvalid,
    output logic        mbx_axil_arready,
    output logic [31:0] mbx_axil_rdata,
    output logic [1:0]  mbx_axil_rresp,
    output logic        mbx_axil_rvalid,
    input  logic        mbx_axil_rready
);

    logic [31:0] mailbox_cpu_event_set;
    logic [31:0] mailbox_host_event_set;
    logic [31:0] combined_cpu_event_set;
    logic [31:0] combined_host_event_set;

    always_comb begin
        combined_cpu_event_set = external_cpu_event_set | mailbox_cpu_event_set;
        combined_host_event_set = external_host_event_set | mailbox_host_event_set;
    end

    axil_interrupt_router interrupt_router (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_event_set(combined_cpu_event_set),
        .host_event_set(combined_host_event_set),
        .cpu_pending(cpu_pending),
        .cpu_mask(cpu_mask),
        .cpu_active(cpu_active),
        .cpu_irq_active(cpu_irq_active),
        .host_pending(host_pending),
        .host_mask(host_mask),
        .host_active(host_active),
        .host_irq_active(host_irq_active),
        .s_axil_awaddr(intr_axil_awaddr),
        .s_axil_awprot(intr_axil_awprot),
        .s_axil_awvalid(intr_axil_awvalid),
        .s_axil_awready(intr_axil_awready),
        .s_axil_wdata(intr_axil_wdata),
        .s_axil_wstrb(intr_axil_wstrb),
        .s_axil_wvalid(intr_axil_wvalid),
        .s_axil_wready(intr_axil_wready),
        .s_axil_bresp(intr_axil_bresp),
        .s_axil_bvalid(intr_axil_bvalid),
        .s_axil_bready(intr_axil_bready),
        .s_axil_araddr(intr_axil_araddr),
        .s_axil_arprot(intr_axil_arprot),
        .s_axil_arvalid(intr_axil_arvalid),
        .s_axil_arready(intr_axil_arready),
        .s_axil_rdata(intr_axil_rdata),
        .s_axil_rresp(intr_axil_rresp),
        .s_axil_rvalid(intr_axil_rvalid),
        .s_axil_rready(intr_axil_rready)
    );

    axil_mailbox mailbox (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_pending(cpu_pending),
        .host_pending(host_pending),
        .cpu_event_set(mailbox_cpu_event_set),
        .host_event_set(mailbox_host_event_set),
        .s_axil_awaddr(mbx_axil_awaddr),
        .s_axil_awprot(mbx_axil_awprot),
        .s_axil_awvalid(mbx_axil_awvalid),
        .s_axil_awready(mbx_axil_awready),
        .s_axil_wdata(mbx_axil_wdata),
        .s_axil_wstrb(mbx_axil_wstrb),
        .s_axil_wvalid(mbx_axil_wvalid),
        .s_axil_wready(mbx_axil_wready),
        .s_axil_bresp(mbx_axil_bresp),
        .s_axil_bvalid(mbx_axil_bvalid),
        .s_axil_bready(mbx_axil_bready),
        .s_axil_araddr(mbx_axil_araddr),
        .s_axil_arprot(mbx_axil_arprot),
        .s_axil_arvalid(mbx_axil_arvalid),
        .s_axil_arready(mbx_axil_arready),
        .s_axil_rdata(mbx_axil_rdata),
        .s_axil_rresp(mbx_axil_rresp),
        .s_axil_rvalid(mbx_axil_rvalid),
        .s_axil_rready(mbx_axil_rready)
    );

endmodule

`default_nettype wire
