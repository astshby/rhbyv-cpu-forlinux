// Module: sim_test_device
// Description: Simulation-only MMIO sink for PASS/FAIL termination writes.
// MMIO（内存映射I/O）,除了没有addr外与dmem一致，用于内存映射
module sim_test_device (
    input  logic                              clk,
    input  logic                              rst,
    input  logic                              req_valid,
    input  logic                              req_write,
    input  logic [core_config_pkg::XLEN-1:0]  req_wdata,
    input  logic [core_config_pkg::DBUS_BYTES-1:0] req_wstrb,  //对于写入dmem的字节进行限制，例如1111就是全写入，传输掩码
    output logic                              req_ready,
    output logic                              rsp_valid,
    output logic [core_config_pkg::XLEN-1:0]  rsp_rdata,
    input  logic                              rsp_ready,
    output logic                           test_done,
    output logic                           test_pass,
    output logic [31:0]                    test_code
);
    assign req_ready = !rsp_valid || rsp_ready;
    assign rsp_rdata = '0;

    always_ff @(posedge clk) begin
        if (rst) begin
            rsp_valid <= 1'b0;
            test_done <= 1'b0;
            test_pass <= 1'b0;
            test_code <= '0;
        end else begin
            if (rsp_valid && rsp_ready)
                rsp_valid <= 1'b0;

            // 读不产生响应，写产生返回响应
            if (req_valid && req_ready) begin
                if (req_write) begin
                    // 结束码固定为低 32 位；忽略不完整写入，RV64 也允许 SW 提交结果。
                    if(&req_wstrb[3:0]) begin
                        test_done <= 1'b1;
                        test_pass <= (req_wdata[31:0] == 32'd1); //写1就是通过
                        test_code <= req_wdata[31:0]; // 保存测试程序写入的结果码
                    end
                end
                else rsp_valid <= 1'b1;
            end
        end
    end
endmodule
