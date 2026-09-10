// Module: predictor_update_arbiter
// Description: Gives older EX updates priority and buffers a simultaneous D1 JAL update.
// EX 指令比 D1 指令更老；一个 pending 槽保存同拍到达的年轻更新。
module predictor_update_arbiter (
    input  logic                       clk,
    input  logic                       rst,
    input  pipeline_pkg::pred_update_t d1_update,
    input  pipeline_pkg::pred_update_t ex_update,
    output pipeline_pkg::pred_update_t update,
    output logic                       overflow
);
    import pipeline_pkg::*;

    pred_update_t pending_q;

    // 单端口选择：EX > pending > D1。
    always_comb begin
        if (ex_update.valid)
            update = ex_update;
        else if (pending_q.valid)
            update = pending_q;
        else
            update = d1_update;
        overflow = ex_update.valid && pending_q.valid && d1_update.valid;
    end

    // pending 管理：EX 占用端口时缓存 D1，pending 发出后可由新 D1 接替。
    always_ff @(posedge clk) begin
        if (rst) begin
            pending_q <= '0;
        end else if (ex_update.valid) begin
            if (d1_update.valid && !pending_q.valid)
                pending_q <= d1_update;
        end else if (pending_q.valid) begin
            if (d1_update.valid)
                pending_q <= d1_update;
            else
                pending_q <= '0;
        end else begin
            pending_q <= '0;
        end
    end
endmodule
