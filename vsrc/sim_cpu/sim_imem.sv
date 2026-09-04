// Module: sim_imem
// Description: Non-synthesizable one-cycle instruction memory model.
// 指令mem，包含一个简单的‘axi握手协议’
module sim_imem #(
    parameter int unsigned DEPTH_WORDS = 4096
) (
    // req：访存需要的 rsp：访存返回的
    input  logic                              clk,
    input  logic                              rst,
    input  logic                              req_valid,
    input  logic [core_config_pkg::XLEN-1:0]  req_addr,
    output logic                              req_ready, //始终返回ready+valid
    output logic                              rsp_valid,
    output logic [31:0]                       rsp_data   // 指令恒定为32位
);
    logic [31:0] mem [0:DEPTH_WORDS-1];

    assign req_ready = 1'b1; //由于imem不拒绝，所以恒定为1

    always_ff @(posedge clk) begin
        if (rst) begin
            rsp_valid <= 1'b0;
        end else begin
            rsp_valid <= req_valid && req_ready;
            if (req_valid && req_ready)
                rsp_data <= mem[req_addr[2 +: $clog2(DEPTH_WORDS)]];
                // 语法解析：req_addr[2 +: $clog2(DEPTH_WORDS)]，表示从req_addr的第2位开始，取$clog2(DEPTH_WORDS)位作为索引，访问mem数组。
                // 4096下，就包含了省去了低两位的地址+映射(req_addr[13：2])
        end
    end
endmodule
