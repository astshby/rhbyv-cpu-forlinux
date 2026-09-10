// Module: pipeline_ctrl
// Description: Selects the oldest control event and assigns one action to each pipeline register.
// 接收已经确认的信号，传递流水线控制信息
module pipeline_ctrl (
    input  pipeline_pkg::redirect_t wb_redirect,
    input  pipeline_pkg::redirect_t ex_redirect,
    input  pipeline_pkg::redirect_t d1_redirect,
    input  logic                    wb_wait,
    input  logic                    mem_request_stall,
    input  logic                    load_use_stall,
    output pipeline_pkg::redirect_t redirect, //以上选择后都给if阶段
    output pipeline_pkg::pipeline_actions_t actions
);
    import pipeline_pkg::*;

    // 根据优先级划分：none，wb重定向（ecall，ebreak），wb等待（load）
    // mem等待（store），ex重定向，load-use冒险，d1重定向（必须要等load-use结束，否则覆盖d2阶段指令）
    typedef enum logic [2:0] {
        CTRL_NONE,
        CTRL_WB_REDIRECT,
        CTRL_WB_WAIT,
        CTRL_MEM_REQUEST_WAIT,
        CTRL_EX_REDIRECT,
        CTRL_LOAD_USE,
        CTRL_D1_REDIRECT
    } control_event_e;

    control_event_e selected_event;

    // 项目选择：每次只选择一个最高优先级事件，顺序由老指令到年轻指令。
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
        else if (load_use_stall)
            selected_event = CTRL_LOAD_USE;
        else if (d1_redirect.valid)
            selected_event = CTRL_D1_REDIRECT;
    end

    // 重定向：只有被选中的重定向才能修改 PC；等待期间保留年轻指令。
    always_comb begin
        redirect = '0;
        unique case (selected_event)
            CTRL_WB_REDIRECT: redirect = wb_redirect;
            CTRL_EX_REDIRECT: redirect = ex_redirect;
            CTRL_D1_REDIRECT: redirect = d1_redirect;
            default: ;
        endcase
    end


    // 流水线信号：bubble 与 flush 都归一为 CLEAR，区别只在触发原因和清除范围。
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
            CTRL_EX_REDIRECT: begin
                actions.if_d1 = PIPE_CLEAR;
                actions.d1_d2 = PIPE_CLEAR;
                actions.d2_ex = PIPE_CLEAR;
            end
            CTRL_LOAD_USE: begin
                actions.if_d1 = PIPE_HOLD;
                actions.d1_d2 = PIPE_HOLD;
                actions.d2_ex = PIPE_CLEAR;
            end
            CTRL_D1_REDIRECT: begin
                actions.if_d1 = PIPE_CLEAR;
            end
            default: ;
        endcase
    end
endmodule
