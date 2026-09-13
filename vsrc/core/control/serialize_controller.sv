// Module: serialize_controller
// Description: Blocks fetch while serialization drains and cancels it on an older redirect.
// 开始序列化时清空年轻取指，直到 WB 完成该事件，或更老的重定向将其取消。
module serialize_controller (
    input  logic clk,
    input  logic rst,
    input  logic serialize_start,
    input  logic serialize_complete,
    output logic frontend_flush,
    output logic fetch_request_enable
);
    logic serialize_pending_q;

    // serialize_start 立刻清空前端；同拍更老的重定向拥有取消优先级。
    // 序列化开始或 pending 期间都不允许继续发起取指请求。
    always_comb begin
        frontend_flush = serialize_start && !serialize_complete;
        fetch_request_enable = !serialize_pending_q && !serialize_start;
    end

    // 重定向可以完成当前 Trap/MRET，也可以取消错误路径上的年轻序列化请求。
    always_ff @(posedge clk) begin
        if (rst || serialize_complete)
            serialize_pending_q <= 1'b0;
        else if (serialize_start)
            serialize_pending_q <= 1'b1;
    end
endmodule
