// Module: if_stage
// Description: Issues ordered fetch requests, buffers responses, and kills redirected paths.
module if_stage (
    input  logic                              clk,
    input  logic                              rst,
    input  logic                              fetch_enable, // 关闭时停止新请求，不影响已经返回的指令
    input  logic                              out_ready, // D1 可以接收 out_packet
    input  pipeline_pkg::redirect_t           redirect,
    input  pipeline_pkg::pred_info_t          prediction,
    output pipeline_pkg::if_d1_t              out_packet,
    output logic                              imem_req_valid,
    output logic [core_config_pkg::XLEN-1:0]  imem_req_addr,
    input  logic                              imem_req_ready,
    input  logic                              imem_rsp_valid,
    input  logic [31:0]                       imem_rsp_data,
    output logic                              imem_rsp_ready
);
    import core_config_pkg::*;
    import core_types_pkg::*;
    import pipeline_pkg::*;

    // IF 最多保留一个未完成请求和一个已返回但 D1 尚未接收的响应。
    xlen_t pc_q;
    if_d1_t request_q; // 已接受请求的 PC/seq_pc/预测元数据
    if_d1_t buffer_q; // D1 暂停时保存已经返回的指令
    logic request_killed_q; // redirect 后等待并丢弃旧路径响应

    if_d1_t response_packet;
    logic response_can_buffer;
    logic response_fire;
    logic response_usable;
    logic request_fire;

    // 1. imem：req_valid与rsp_ready 由 IF 发出，其余由 IMEM/Cache 返回。
    always_comb begin
        // response_fire 是respose响应后的信号，request_fire是request请求握手后的结果
        imem_req_valid = fetch_enable && !redirect.valid &&
                         (!request_q.valid || response_fire);
        imem_req_addr = pc_q;
        // 空闲：在request有效时，上一次请求被杀死/重定向/response已经被接收
        imem_rsp_ready = request_q.valid &&
                         (request_killed_q || redirect.valid || response_can_buffer);
    end

    // 2. 握手与响应：buffer 空闲、即将出队或响应已被 kill 时都可以接收。response_packet.valid重赋值
    always_comb begin
        response_can_buffer = !buffer_q.valid || out_ready;
        request_fire = imem_req_valid && imem_req_ready;
        response_fire = imem_rsp_valid && imem_rsp_ready;
        response_usable = response_fire && !request_killed_q && !redirect.valid;
        response_packet = request_q;
        response_packet.inst = imem_rsp_data;
        response_packet.valid = response_usable;
    end

    // 3. 输出选择：buffer 优先，否则允许新响应直接送往 D1。
    always_comb begin
        out_packet = buffer_q;
        if (!buffer_q.valid)
            out_packet = response_packet;
        // redirect 需要清空 out_packet
        if (redirect.valid)
            out_packet.valid = 1'b0;
    end

    // 4. PC 状态：只有请求真正被接受后才推进；redirect 优先切换取指地址。
    always_ff @(posedge clk) begin
        if (rst) pc_q <= RESET_VECTOR;
        else if (redirect.valid) pc_q <= redirect.pc;
        else if (request_fire)
            pc_q <= prediction.taken ? prediction.target : pc_q + xlen_t'(4);
    end

    // 5. request处理：响应完成时释放旧槽，同拍可保存下一笔请求。
    always_ff @(posedge clk) begin
        if (rst) begin
            request_q <= '0;
            request_killed_q <= 1'b0;
        end
        else if (redirect.valid) begin
            // 重定向时，上一条指令没有返回但仍然请求旧必须杀死，其余直接无效
            if (request_q.valid && !response_fire)
                request_killed_q <= 1'b1;
            else begin
                request_q.valid <= 1'b0;
                request_killed_q <= 1'b0;
            end
        end
        else begin
            // 响应完成先清除，后面再次请求会覆盖
            if (response_fire) begin
                request_q.valid <= 1'b0;
                request_killed_q <= 1'b0;
            end
            if (request_fire) begin
                request_q.valid <= 1'b1;
                request_q.pc <= pc_q;
                request_q.seq_pc <= pc_q + xlen_t'(4);
                request_q.inst <= '0;
                request_q.pred <= prediction;
                request_killed_q <= 1'b0;
            end
        end
    end

    // 6. buffer处理：覆盖“旧包出队且新响应同拍到达”的连续传输情况。(buffer out_ready的四种情况)
    // 处理b1q1与b0q0，b1q0不变，b0q1直接buffer_can_buffer取出(此时req要有效)
    always_ff @(posedge clk) begin
        if (rst || redirect.valid)
            buffer_q <= '0;
        else if (buffer_q.valid && out_ready) begin
            if (response_usable) //已经包含了必须的kill无效,可以将下一个给buffer
                buffer_q <= response_packet;
            else
                buffer_q.valid <= 1'b0;   //无效的必须清除
        end
        else if (!buffer_q.valid && !out_ready && response_usable)  //已经包含buffer_q.valid=0了
            buffer_q <= response_packet;
    end
endmodule
