// Module: serialize_controller
// Description: Blocks new fetches while an exception or MRET drains to WB.
// 标记异常处理：开始处理时清空年轻取指，并保持停取指状态直到 WB 产生最终重定向。
module serialize_controller (
    input  logic clk,
    input  logic rst,
    input  logic serialize_start,
    input  logic serialize_complete,
    output logic frontend_flush,
    output logic fetch_request_enable
);
    logic serialize_pending_q;

    // frontend_flush:start立刻清空并且必须要结束(wb_redirect.valid)才结束清空
    // fetch_request_enable:当serilaize开始，或pending进行都不允许fetch_request_enable
    always_comb begin
        frontend_flush = serialize_start && !serialize_complete;
        fetch_request_enable = !serialize_pending_q && !serialize_start;
    end

    // WB Trap/MRET 重定向结束本次序列化，完成事件优先于新的开始事件。
    always_ff @(posedge clk) begin
        if (rst || serialize_complete)
            serialize_pending_q <= 1'b0;
        else if (serialize_start)
            serialize_pending_q <= 1'b1;
    end
endmodule
