// Module: core
// Description: Portable single-issue IF-D1-D2-EX-MEM-WB in-order core.
module core (
    // 端口声明中使用包类型时需要写完整包名
    input  logic                              clk,
    input  logic                              rst,
    output logic                              imem_req_valid,
    output logic [core_config_pkg::XLEN-1:0]  imem_req_addr,
    input  logic                              imem_req_ready,
    input  logic                              imem_rsp_valid,
    input  logic [31:0]                       imem_rsp_data,
    output logic                              imem_rsp_ready,
    output logic                              dmem_req_valid,
    output logic                              dmem_req_write,
    output logic [core_config_pkg::XLEN-1:0]  dmem_req_addr,
    output logic [core_config_pkg::XLEN-1:0]  dmem_req_wdata,
    output logic [core_config_pkg::DBUS_BYTES-1:0] dmem_req_wstrb,
    input  logic                              dmem_req_ready,
    input  logic                              dmem_rsp_valid,
    input  logic [core_config_pkg::XLEN-1:0]  dmem_rsp_rdata,
    output logic                              dmem_rsp_ready,
    // commit 用于退休统计、差分测试和波形调试。
    output logic                              commit_valid,
    output logic [core_config_pkg::XLEN-1:0]  commit_pc,
    output logic [31:0]                       commit_inst,
    output logic [core_config_pkg::GPR_ADDR_W-1:0] commit_rd,
    output logic                              commit_rd_we,
    output logic [core_config_pkg::XLEN-1:0]  commit_rd_data,
    output logic                              commit_exception
);
    import core_config_pkg::*;
    import core_types_pkg::*;
    import pipeline_pkg::*;

    // 用于接口的定义
    // 1. 六级流水线的五组级间寄存器，_q 表示是时序逻辑（真正的级间寄存器）
    if_d1_t if_d1_q;
    d1_d2_t d1_d2_q;
    d2_ex_t d2_ex_q;
    ex_mem_t ex_mem_q;
    mem_wb_t mem_wb_q;

    if_d1_t fetch_packet;
    d1_d2_t d1_packet;
    d2_ex_t d2_packet;
    ex_mem_t ex_packet;
    mem_wb_t mem_packet;

    // 2. 预测与重定向。
    pred_info_t prediction;
    redirect_t d1_redirect;
    redirect_t ex_redirect;
    redirect_t wb_redirect;
    redirect_t selected_redirect;
    pred_update_t d1_update_raw;
    pred_update_t ex_update_raw;
    pred_update_t d1_update;
    pred_update_t ex_update;
    pred_update_t predictor_update;

    // 3. GPR 读写和前递。
    xlen_t rs1_data;
    xlen_t rs2_data;
    logic gpr_write_enable;
    gpr_addr_t gpr_write_addr;
    xlen_t gpr_write_data;
    logic mem_forward_valid;
    gpr_addr_t mem_forward_addr;
    xlen_t mem_forward_data;

    // 4. 冒险、存储器反压与流水线动作。
    logic load_use_stall;
    logic mem_request_stall;
    logic wb_wait;
    logic mem_issue_enable;
    pipeline_actions_t pipeline_actions;
    logic fetch_ready;
    logic d1_stage_advance;
    logic ex_stage_advance;
    logic predictor_overflow;


    // 各个功能模块与流水线
    // 断言仅用于仿真与 lint。
`ifndef SYNTHESIS
    initial begin
        assert ((XLEN == 32) || (XLEN == 64))
            else $error("CORE_XLEN must be 32 or 64");
    end
`endif

    // 当前 A3 尚未接入 WB trap 重定向。
    always_comb begin
        wb_redirect = '0;
    end

    // 预测器需要的更新信息，只有流水级真正推进时才允许训练，避免停顿包重复更新或错误路径更新。
    always_comb begin
        d1_stage_advance = if_d1_q.valid &&
                           (pipeline_actions.d1_d2 == PIPE_ADVANCE);
        ex_stage_advance = d2_ex_q.valid &&
                           (pipeline_actions.ex_mem == PIPE_ADVANCE);
        d1_update = d1_update_raw;
        ex_update = ex_update_raw;
        d1_update.valid = d1_update_raw.valid && d1_stage_advance;
        ex_update.valid = ex_update_raw.valid && ex_stage_advance;
    end

    predictor_update_arbiter u_predictor_update_arbiter (
        .clk,
        .rst,
        .d1_update,
        .ex_update,
        .update(predictor_update),
        .overflow(predictor_overflow)
    );

    predictor u_predictor (
        .clk,
        .rst,
        .lookup_pc(imem_req_addr),
        .prediction,
        .update(predictor_update)
    );

    // 更新端口持续过载表示预测器丢失了一次训练，只在仿真中报错。
`ifndef SYNTHESIS
    always_ff @(posedge clk) begin
        if (!rst)
            assert (!predictor_overflow)
                else $error("predictor update pending buffer overflow");
    end
`endif

    // IF,MEM需要的imem，dmem控制信号
    always_comb begin
        // fetch_ready:只要不停顿都可以收
        fetch_ready = (pipeline_actions.if_d1 != PIPE_HOLD);
        // WB 等响应或正在执行重定向时，禁止 MEM 发出请求。
        mem_issue_enable = !wb_wait && !wb_redirect.valid;
    end

    // 各功能单元连线,连线后的包经过valid修改才交给流水级寄存器
    if_stage u_if_stage (
        .clk,
        .rst,
        .fetch_enable(1'b1), // 当前始终允许取指
        .out_ready(fetch_ready),
        .redirect(selected_redirect),
        .prediction,
        .out_packet(fetch_packet),
        .imem_req_valid,
        .imem_req_addr,
        .imem_req_ready,
        .imem_rsp_valid,
        .imem_rsp_data,
        .imem_rsp_ready
    );

    d1_stage u_d1_stage (
        .in_packet(if_d1_q),
        .out_packet(d1_packet),
        .redirect(d1_redirect),
        .pred_update(d1_update_raw)
    );

    regfile u_regfile (
        .clk,
        .rs1_addr(d1_d2_q.rs1),
        .rs2_addr(d1_d2_q.rs2),
        .rs1_data,
        .rs2_data,
        .write_enable(gpr_write_enable),
        .write_addr(gpr_write_addr),
        .write_data(gpr_write_data)
    );

    d2_stage u_d2_stage (
        .in_packet(d1_d2_q),
        .rs1_data,
        .rs2_data,
        .out_packet(d2_packet)
    );

    ex_stage u_ex_stage (
        .in_packet(d2_ex_q),
        .mem_forward_valid,
        .mem_forward_addr,
        .mem_forward_data,
        .wb_forward_valid(gpr_write_enable),
        .wb_forward_addr(gpr_write_addr),
        .wb_forward_data(gpr_write_data),
        .out_packet(ex_packet),
        .redirect(ex_redirect),
        .pred_update(ex_update_raw)
    );

    mem_stage u_mem_stage (
        .issue_enable(mem_issue_enable),
        .in_packet(ex_mem_q),
        .dmem_req_valid,
        .dmem_req_write,
        .dmem_req_addr,
        .dmem_req_wdata,
        .dmem_req_wstrb,
        .dmem_req_ready,
        .out_packet(mem_packet),
        .request_stall(mem_request_stall),
        .forward_valid(mem_forward_valid),
        .forward_addr(mem_forward_addr),
        .forward_data(mem_forward_data)
    );

    wb_stage u_wb_stage (
        .in_packet(mem_wb_q),
        .dmem_rsp_valid,
        .dmem_rsp_rdata,
        .dmem_rsp_ready,
        .wait_for_response(wb_wait),
        .gpr_write_enable,
        .gpr_write_addr,
        .gpr_write_data,
        .commit_valid,
        .commit_pc,
        .commit_inst,
        .commit_rd,
        .commit_rd_we,
        .commit_rd_data,
        .commit_exception
    );

    hazard_unit u_hazard_unit (
        .producer(d2_ex_q),
        .consumer(d1_d2_q),
        .load_use_stall
    );

    pipeline_ctrl u_pipeline_ctrl (
        .wb_redirect,
        .ex_redirect,
        .d1_redirect,
        .wb_wait,
        .mem_request_stall,
        .load_use_stall,
        .redirect(selected_redirect),
        .actions(pipeline_actions)
    );

    // 流水级间寄存器
    always_ff @(posedge clk) begin
        if (rst)
            if_d1_q <= '0;
        else if (pipeline_actions.if_d1 == PIPE_CLEAR)
            if_d1_q.valid <= 1'b0;
        else if (pipeline_actions.if_d1 == PIPE_ADVANCE)
            if_d1_q <= fetch_packet;
    end

    always_ff @(posedge clk) begin
        if (rst)
            d1_d2_q <= '0;
        else if (pipeline_actions.d1_d2 == PIPE_CLEAR)
            d1_d2_q.valid <= 1'b0;
        else if (pipeline_actions.d1_d2 == PIPE_ADVANCE)
            d1_d2_q <= d1_packet;
    end

    always_ff @(posedge clk) begin
        if (rst)
            d2_ex_q <= '0;
        else if (pipeline_actions.d2_ex == PIPE_CLEAR)
            d2_ex_q.valid <= 1'b0;
        else if (pipeline_actions.d2_ex == PIPE_ADVANCE)
            d2_ex_q <= d2_packet;
    end

    always_ff @(posedge clk) begin
        if (rst)
            ex_mem_q <= '0;
        else if (pipeline_actions.ex_mem == PIPE_CLEAR)
            ex_mem_q.valid <= 1'b0;
        else if (pipeline_actions.ex_mem == PIPE_ADVANCE)
            ex_mem_q <= ex_packet;
    end

    always_ff @(posedge clk) begin
        if (rst)
            mem_wb_q <= '0;
        else if (pipeline_actions.mem_wb == PIPE_CLEAR)
            mem_wb_q.valid <= 1'b0;
        else if (pipeline_actions.mem_wb == PIPE_ADVANCE)
            mem_wb_q <= mem_packet;
    end

endmodule
