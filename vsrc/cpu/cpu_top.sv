// Module: cpu_top
// Description: Synthesizable FPGA integration boundary; BRAM IP is added in A6.
module cpu_top (
    input  logic clk,
    input  logic reset_n
);
    import core_config_pkg::*;

    logic rst;
    logic imem_req_valid;
    logic [XLEN-1:0] imem_req_addr;
    logic dmem_req_valid;
    logic dmem_req_write;
    logic [XLEN-1:0] dmem_req_addr;
    logic [XLEN-1:0] dmem_req_wdata;
    logic [DBUS_BYTES-1:0] dmem_req_wstrb;

    reset_sync u_reset_sync (
        .clk,
        .reset_n,
        .rst
    );

    core u_core (
        .clk,
        .rst,
        .imem_req_valid,
        .imem_req_addr,
        .imem_req_ready(1'b0),
        .imem_rsp_valid(1'b0),
        .imem_rsp_data('0),
        .dmem_req_valid,
        .dmem_req_write,
        .dmem_req_addr,
        .dmem_req_wdata,
        .dmem_req_wstrb,
        .dmem_req_ready(1'b0),
        .dmem_rsp_valid(1'b0),
        .dmem_rsp_rdata('0),
        .commit_valid(),
        .commit_pc(),
        .commit_inst(),
        .commit_rd(),
        .commit_rd_we(),
        .commit_rd_data(),
        .commit_exception()
    );
endmodule
