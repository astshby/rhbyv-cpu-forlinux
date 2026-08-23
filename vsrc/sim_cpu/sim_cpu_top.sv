// Module: sim_cpu_top
// Description: Simulation-only wrapper around the portable core and memories.
module sim_cpu_top (
    input  logic                              clk,
    input  logic                              rst,
    output logic                              commit_valid,
    output logic [core_config_pkg::XLEN-1:0] commit_pc,
    output logic [31:0]                       commit_inst,
    output logic [core_config_pkg::GPR_ADDR_W-1:0] commit_rd,
    output logic                              commit_rd_we,
    output logic [core_config_pkg::XLEN-1:0] commit_rd_data,
    output logic                              commit_exception
);
    import core_config_pkg::*;

    logic imem_req_valid;
    logic [XLEN-1:0] imem_req_addr;
    logic imem_req_ready;
    logic imem_rsp_valid;
    logic [31:0] imem_rsp_data;
    logic dmem_req_valid;
    logic dmem_req_write;
    logic [XLEN-1:0] dmem_req_addr;
    logic [XLEN-1:0] dmem_req_wdata;
    logic [DBUS_BYTES-1:0] dmem_req_wstrb;
    logic dmem_req_ready;
    logic dmem_rsp_valid;
    logic [XLEN-1:0] dmem_rsp_rdata;

    core u_core (
        .clk,
        .rst,
        .imem_req_valid,
        .imem_req_addr,
        .imem_req_ready,
        .imem_rsp_valid,
        .imem_rsp_data,
        .dmem_req_valid,
        .dmem_req_write,
        .dmem_req_addr,
        .dmem_req_wdata,
        .dmem_req_wstrb,
        .dmem_req_ready,
        .dmem_rsp_valid,
        .dmem_rsp_rdata,
        .commit_valid,
        .commit_pc,
        .commit_inst,
        .commit_rd,
        .commit_rd_we,
        .commit_rd_data,
        .commit_exception
    );

    sim_imem u_imem (
        .clk,
        .rst,
        .req_valid(imem_req_valid),
        .req_addr(imem_req_addr),
        .req_ready(imem_req_ready),
        .rsp_valid(imem_rsp_valid),
        .rsp_data(imem_rsp_data)
    );

    sim_dmem u_dmem (
        .clk,
        .rst,
        .req_valid(dmem_req_valid),
        .req_write(dmem_req_write),
        .req_addr(dmem_req_addr),
        .req_wdata(dmem_req_wdata),
        .req_wstrb(dmem_req_wstrb),
        .req_ready(dmem_req_ready),
        .rsp_valid(dmem_rsp_valid),
        .rsp_rdata(dmem_rsp_rdata)
    );
endmodule
