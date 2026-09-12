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
    import riscv_priv_pkg::*;

    // 1. 六级流水线的五组级间寄存器；_q 表示真正的时序状态。
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

    // 2. 预测、重定向与错误路径清理。
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
    logic predictor_overflow;
    logic predictor_flush;

    // 3. GPR 读写和前递。
    xlen_t rs1_data;
    xlen_t rs2_data;
    logic gpr_write_enable;
    gpr_addr_t gpr_write_addr;
    xlen_t gpr_write_data;
    logic mem_forward_valid;
    gpr_addr_t mem_forward_addr;
    xlen_t mem_forward_data;

    // 4. CSR 读取、旁路、提交与 Trap 状态。
    xlen_t csr_committed_data;
    xlen_t csr_old_data;
    logic csr_access_illegal;
    logic csr_write_valid;
    logic trap_enter;
    logic mret_commit;
    xlen_t trap_pc;
    exc_cause_e trap_cause;
    xlen_t trap_tval;
    logic retire_valid;
    xlen_t mtvec;
    xlen_t mepc;

    // 5. 冒险、存储器反压、序列化与流水线动作。
    logic load_use_stall;
    logic mem_request_stall;
    logic wb_wait;
    logic mem_issue_enable;
    pipeline_actions_t pipeline_actions;
    logic fetch_ready;
    logic d1_stage_advance;
    logic ex_stage_advance;
    logic d1_serialize;
    logic ex_serialize;
    logic frontend_flush;
    logic fetch_enable;
    logic serial_pending_q;

    // 参数断言仅用于仿真与 lint。
`ifndef SYNTHESIS
    initial begin
        assert ((XLEN == 32) || (XLEN == 64))
            else $error("CORE_XLEN must be 32 or 64");
    end
`endif

    // 6. 更新放行：只有流水级真正推进时才训练，避免停顿包重复更新。
    // WB/EX 清除 D1 及其后续时，pending 中的年轻预测更新也必须作废。
    always_comb begin
        d1_stage_advance = if_d1_q.valid &&
                           (pipeline_actions.d1_d2 == PIPE_ADVANCE);
        ex_stage_advance = d2_ex_q.valid &&
                           (pipeline_actions.ex_mem == PIPE_ADVANCE);
        d1_update = d1_update_raw;
        ex_update = ex_update_raw;
        d1_update.valid = d1_update_raw.valid && d1_stage_advance;
        ex_update.valid = ex_update_raw.valid && ex_stage_advance &&
                          !ex_packet.exc.valid;
        predictor_flush = (pipeline_actions.d1_d2 == PIPE_CLEAR);
    end

    predictor_update_arbiter u_predictor_update_arbiter (
        .clk,
        .rst,
        .flush(predictor_flush),
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

    // 7. 序列化检测：D1 识别译码异常/MRET，EX 补充 CSR、对齐和控制流异常。
    always_comb begin
        d1_serialize = if_d1_q.valid &&
                       (d1_packet.exc.valid || (d1_packet.uop.sys_op == SYS_MRET));
        ex_serialize = d2_ex_q.valid && ex_packet.exc.valid;
    end

    // 8. IF/MEM 接口控制：flush 只杀死年轻取指，真正的 Trap PC 在 WB 才确定。
    always_comb begin
        fetch_ready = (pipeline_actions.if_d1 != PIPE_HOLD);
        frontend_flush = (pipeline_actions.if_d1 == PIPE_CLEAR) &&
                         !selected_redirect.valid;
        fetch_enable = !serial_pending_q && !frontend_flush;
        // WB 等 Load 响应或正在提交重定向时，禁止 MEM 发出新请求。
        mem_issue_enable = !wb_wait && !wb_redirect.valid;
    end

    // 9. CSR 旁路：较新的 EX/MEM 写优先于 MEM/WB，旁路值已通过 WARL 合法化。
    always_comb begin
        csr_old_data = csr_committed_data;
        if (mem_wb_q.valid && mem_wb_q.csr_we && !mem_wb_q.exc.valid &&
            (mem_wb_q.csr_addr == d2_ex_q.csr_addr))
            csr_old_data = mem_wb_q.csr_new;
        if (ex_mem_q.valid && ex_mem_q.csr_we && !ex_mem_q.exc.valid &&
            (ex_mem_q.csr_addr == d2_ex_q.csr_addr))
            csr_old_data = ex_mem_q.csr_new;

        // CSR 只能在 WB 包及其可能需要的响应真正完整时提交一次。
        csr_write_valid = commit_valid && mem_wb_q.csr_we &&
                          !mem_wb_q.exc.valid;
    end

    // 10. 各功能单元与流水级连线。
    if_stage u_if_stage (
        .clk,
        .rst,
        .fetch_enable,
        .out_ready(fetch_ready),
        .flush(frontend_flush),
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
        .csr_old_data,
        .csr_access_illegal,
        .out_packet(ex_packet),
        .redirect(ex_redirect),
        .pred_update(ex_update_raw)
    );

    csr_access_check u_csr_access_check (
        .address(d2_ex_q.csr_addr),
        .write_intent(d2_ex_q.uop.csr_write),
        .implemented(),
        .read_only(),
        .illegal(csr_access_illegal)
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

    trap_controller u_trap_controller (
        .commit_packet(mem_wb_q),
        .commit_valid,
        .mtvec,
        .mepc,
        .trap_enter,
        .mret_commit,
        .trap_pc,
        .trap_cause,
        .trap_tval,
        .retire_valid,
        .redirect(wb_redirect)
    );

    csr_file u_csr_file (
        .clk,
        .rst,
        .read_addr(d2_ex_q.csr_addr),
        .read_data(csr_committed_data),
        .write_valid(csr_write_valid),
        .write_addr(mem_wb_q.csr_addr),
        .write_data(mem_wb_q.csr_new),
        .retire_valid,
        .trap_enter,
        .trap_pc,
        .trap_cause,
        .trap_tval,
        .mret_commit,
        .mtvec,
        .mepc
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
        .ex_serialize,
        .d1_serialize,
        .wb_wait,
        .mem_request_stall,
        .load_use_stall,
        .redirect(selected_redirect),
        .actions(pipeline_actions)
    );

    // 11. 流水级间寄存器：每个寄存器独立处理 ADVANCE/HOLD/CLEAR。
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

    // 12. 精确异常序列化：发现后停止新取指，直到该指令在 WB 产生 Trap/MRET 重定向。
    always_ff @(posedge clk) begin
        if (rst || wb_redirect.valid)
            serial_pending_q <= 1'b0;
        else if (frontend_flush)
            serial_pending_q <= 1'b1;
    end
endmodule
