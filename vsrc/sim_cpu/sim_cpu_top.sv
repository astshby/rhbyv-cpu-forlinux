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
    output logic                              commit_exception,
    output logic                              test_done,
    output logic                              test_pass,
    output logic [31:0]                       test_code
);
    import core_config_pkg::*;
    import core_types_pkg::*;

    logic imem_req_valid;
    logic [XLEN-1:0] imem_req_addr;
    logic imem_req_ready;
    logic imem_rsp_valid;
    logic [31:0] imem_rsp_data;
    logic imem_rsp_ready;
    logic dmem_req_valid;
    logic dmem_req_write;
    logic [XLEN-1:0] dmem_req_addr;
    logic [XLEN-1:0] dmem_req_wdata;
    logic [DBUS_BYTES-1:0] dmem_req_wstrb;
    logic dmem_req_ready;
    logic dmem_rsp_valid;
    logic [XLEN-1:0] dmem_rsp_rdata;
    logic dmem_rsp_ready;
    logic memory_req_ready;
    logic memory_rsp_valid;
    logic [XLEN-1:0] memory_rsp_rdata;
    logic memory_rsp_ready;
    logic test_req_ready;
    logic test_rsp_valid;
    logic [XLEN-1:0] test_rsp_rdata;
    logic test_rsp_ready;
    logic select_test_device;

    // core对dmem的接收选择
    // select:选择MMIO设备,dmen_rdata,dmen_req_ready,dmen_rsp_valid是core需要的，并且要经过选择
    // 为了端口名字便于匹配，所以要选择(通过地址)
    assign select_test_device = (dmem_req_addr == xlen_t'(32'h1000_0000));
    assign dmem_req_ready = select_test_device ? test_req_ready : memory_req_ready;
    assign dmem_rsp_valid = memory_rsp_valid || test_rsp_valid;
    assign dmem_rsp_rdata = test_rsp_valid ? test_rsp_rdata : memory_rsp_rdata;
    // 返回端以 test device 为高优先级；单发射核心正常情况下不会同时存在两个响应。
    assign test_rsp_ready = dmem_rsp_ready;
    assign memory_rsp_ready = dmem_rsp_ready && !test_rsp_valid;

    // .name是sv特性，可以用 .* 替代（原理：扫描已有同名信号并直接连接，没有的不连接）
    core u_core (
        .clk,
        .rst,
        .imem_req_valid,
        .imem_req_addr,
        .imem_req_ready,
        .imem_rsp_valid,
        .imem_rsp_data,
        .imem_rsp_ready,
        .dmem_req_valid,
        .dmem_req_write,
        .dmem_req_addr,
        .dmem_req_wdata,
        .dmem_req_wstrb,
        .dmem_req_ready,
        .dmem_rsp_valid,
        .dmem_rsp_rdata,
        .dmem_rsp_ready,
        .commit_valid,
        .commit_pc,
        .commit_inst,
        .commit_rd,
        .commit_rd_we,
        .commit_rd_data,
        .commit_exception
    );
    // 等价于 core u_core ( .* );

    sim_imem u_imem (
        .clk,
        .rst,
        .req_valid(imem_req_valid),
        .req_addr(imem_req_addr),
        .req_ready(imem_req_ready),
        .rsp_valid(imem_rsp_valid),
        .rsp_data(imem_rsp_data),
        .rsp_ready(imem_rsp_ready)
    );

    sim_dmem u_dmem (
        .clk,
        .rst,
        .req_valid(dmem_req_valid && !select_test_device), //通过有效信号，实现了类似write的选择功能，梗准确
        .req_write(dmem_req_write),
        .req_addr(dmem_req_addr),
        .req_wdata(dmem_req_wdata),
        .req_wstrb(dmem_req_wstrb),
        .req_ready(memory_req_ready),
        .rsp_valid(memory_rsp_valid),
        .rsp_rdata(memory_rsp_rdata),
        .rsp_ready(memory_rsp_ready)
    );

    sim_test_device u_test_device (
        .clk,
        .rst,
        .req_valid(dmem_req_valid && select_test_device), //选择test，则有效，否则无效（87行）
        .req_write(dmem_req_write),
        .req_wdata(dmem_req_wdata),
        .req_wstrb(dmem_req_wstrb),
        .req_ready(test_req_ready),
        .rsp_valid(test_rsp_valid),
        .rsp_rdata(test_rsp_rdata),
        .rsp_ready(test_rsp_ready),
        .test_done,
        .test_pass,
        .test_code
    );
endmodule
