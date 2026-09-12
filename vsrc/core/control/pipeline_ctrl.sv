// Module: pipeline_ctrl
// Description: Selects the oldest control event and assigns one action to each pipeline register.
// 接收已经确认的信号，传递流水线控制信息
module pipeline_ctrl (
    input  pipeline_pkg::redirect_t wb_redirect,
    input  pipeline_pkg::redirect_t ex_redirect,
    input  pipeline_pkg::redirect_t d1_redirect,
    input  logic                    ex_serialize,
    input  logic                    d1_serialize,
    input  logic                    wb_wait,
    input  logic                    mem_request_stall,
    input  logic                    load_use_stall,
    output pipeline_pkg::redirect_t redirect, // 以上选择后都给 IF 阶段
    output pipeline_pkg::pipeline_actions_t actions
);
    import pipeline_pkg::*;

    // 每拍只选择一个事件，优先级严格按照流水线中指令由老到年轻排列。
    typedef enum logic [3:0] {
        CTRL_NONE,
        CTRL_WB_REDIRECT,
        CTRL_WB_WAIT,
        CTRL_MEM_REQUEST_WAIT,
        CTRL_EX_REDIRECT,
        CTRL_EX_SERIALIZE,
        CTRL_LOAD_USE,
        CTRL_D1_REDIRECT,
        CTRL_D1_SERIALIZE
    } control_event_e;

    control_event_e selected_event;

    // 1. 事件仲裁：等待旧指令时，年轻级的重定向或序列化必须延后处理。
    always_comb begin
        selected_event = CTRL_NONE;
        if (wb_redirect.valid)
            selected_event = CTRL_WB_REDIRECT;
        else if (wb_wait)
            selected_event = CTRL_WB_WAIT;
        else if (mem_request_stall)
            selected_event = CTRL_MEM_REQUEST_WAIT;
        else if (ex_redirect.valid)
            selected_event = CTRL_EX_REDIRECT;
        else if (ex_serialize)
            selected_event = CTRL_EX_SERIALIZE;
        else if (load_use_stall)
            selected_event = CTRL_LOAD_USE;
        else if (d1_redirect.valid)
            selected_event = CTRL_D1_REDIRECT;
        else if (d1_serialize)
            selected_event = CTRL_D1_SERIALIZE;
    end

    // 2. PC 重定向：序列化只清除年轻指令，本身不直接给出新 PC。
    always_comb begin
        redirect = '0;
        unique case (selected_event)
            CTRL_WB_REDIRECT: redirect = wb_redirect;
            CTRL_EX_REDIRECT: redirect = ex_redirect;
            CTRL_D1_REDIRECT: redirect = d1_redirect;
            default: ;
        endcase
    end

    // 3. 流水线动作：bubble 与 flush 统一为 CLEAR，区别只在触发原因和清除范围。
    always_comb begin
        actions.if_d1 = PIPE_ADVANCE;
        actions.d1_d2 = PIPE_ADVANCE;
        actions.d2_ex = PIPE_ADVANCE;
        actions.ex_mem = PIPE_ADVANCE;
        actions.mem_wb = PIPE_ADVANCE;

        unique case (selected_event)
            CTRL_WB_REDIRECT: begin
                actions.if_d1 = PIPE_CLEAR;
                actions.d1_d2 = PIPE_CLEAR;
                actions.d2_ex = PIPE_CLEAR;
                actions.ex_mem = PIPE_CLEAR;
                actions.mem_wb = PIPE_CLEAR;
            end
            CTRL_WB_WAIT: begin
                actions.if_d1 = PIPE_HOLD;
                actions.d1_d2 = PIPE_HOLD;
                actions.d2_ex = PIPE_HOLD;
                actions.ex_mem = PIPE_HOLD;
                actions.mem_wb = PIPE_HOLD;
            end
            CTRL_MEM_REQUEST_WAIT: begin
                actions.if_d1 = PIPE_HOLD;
                actions.d1_d2 = PIPE_HOLD;
                actions.d2_ex = PIPE_HOLD;
                actions.ex_mem = PIPE_HOLD;
            end
            CTRL_EX_REDIRECT, CTRL_EX_SERIALIZE: begin
                actions.if_d1 = PIPE_CLEAR;
                actions.d1_d2 = PIPE_CLEAR;
                actions.d2_ex = PIPE_CLEAR;
            end
            CTRL_LOAD_USE: begin
                actions.if_d1 = PIPE_HOLD;
                actions.d1_d2 = PIPE_HOLD;
                actions.d2_ex = PIPE_CLEAR;
            end
            CTRL_D1_REDIRECT, CTRL_D1_SERIALIZE: begin
                actions.if_d1 = PIPE_CLEAR;
            end
            default: ;
        endcase
    end
endmodule
