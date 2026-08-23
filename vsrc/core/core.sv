// Module: core
// Description: Portable six-stage core boundary; datapath is added in stage A1.
module core (
    input  logic                              clk,
    input  logic                              rst,
    output logic                              imem_req_valid,
    output logic [core_config_pkg::XLEN-1:0] imem_req_addr,
    input  logic                              imem_req_ready,
    input  logic                              imem_rsp_valid,
    input  logic [31:0]                       imem_rsp_data,
    output logic                              dmem_req_valid,
    output logic                              dmem_req_write,
    output logic [core_config_pkg::XLEN-1:0] dmem_req_addr,
    output logic [core_config_pkg::XLEN-1:0] dmem_req_wdata,
    output logic [core_config_pkg::DBUS_BYTES-1:0] dmem_req_wstrb,
    input  logic                              dmem_req_ready,
    input  logic                              dmem_rsp_valid,
    input  logic [core_config_pkg::XLEN-1:0] dmem_rsp_rdata,
    output logic                              commit_valid,
    output logic [core_config_pkg::XLEN-1:0] commit_pc,
    output logic [31:0]                       commit_inst,
    output logic [core_config_pkg::GPR_ADDR_W-1:0] commit_rd,
    output logic                              commit_rd_we,
    output logic [core_config_pkg::XLEN-1:0] commit_rd_data,
    output logic                              commit_exception
);
    import core_config_pkg::*;

    initial begin
        assert ((XLEN == 32) || (XLEN == 64))
            else $error("CORE_XLEN must be 32 or 64");
    end

    always_comb begin
        imem_req_valid = 1'b0;
        imem_req_addr = RESET_VECTOR;
        dmem_req_valid = 1'b0;
        dmem_req_write = 1'b0;
        dmem_req_addr = '0;
        dmem_req_wdata = '0;
        dmem_req_wstrb = '0;
        commit_valid = 1'b0;
        commit_pc = '0;
        commit_inst = '0;
        commit_rd = '0;
        commit_rd_we = 1'b0;
        commit_rd_data = '0;
        commit_exception = 1'b0;
    end

    logic unused_inputs;
    assign unused_inputs = ^{clk, rst, imem_req_ready, imem_rsp_valid, imem_rsp_data,
                             dmem_req_ready, dmem_rsp_valid, dmem_rsp_rdata};
endmodule
